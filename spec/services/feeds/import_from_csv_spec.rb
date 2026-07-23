require 'rails_helper'

RSpec.describe Feeds::ImportFromCsv do
  let(:validator) { instance_double(Feeds::FeedContentValidator, validate!: true) }

  def import(csv)
    described_class.new(csv, validator: validator).call
  end

  it 'imports valid rows and creates missing categories' do
    result = import("title,category,feed_url\nNews,Research,https://example.com/news.xml\n")

    expect(result.imported.first).to include('title' => 'News', 'category_status' => 'created', 'row' => 2)
    expect(result.unimported).to be_empty
    expect(Feed.last.feed_category.name).to eq('Research')
  end

  it 'reuses categories case-insensitively' do
    category = create(:feed_category, name: 'research')

    result = import("title,category,feed_url\nNews,RESEARCH,https://example.com/news.xml\n")

    expect(result.imported.first['category_status']).to eq('reused')
    expect(Feed.last.feed_category).to eq(category)
    expect(FeedCategory.count).to eq(1)
  end

  it 'accepts a UTF-8 BOM' do
    result = import("\uFEFFtitle,category,feed_url\nNews,Research,https://example.com/news.xml\n")

    expect(result.imported.size).to eq(1)
  end

  it 'rejects missing required headers before creating records' do
    original_count = Feed.count

    expect { import("title,feed_url\nNews,https://example.com/news.xml\n") }
      .to raise_error(described_class::FileError, /missing required header.*category/)
    expect(Feed.count).to eq(original_count)
  end

  it 'rejects malformed CSV before creating records' do
    original_count = Feed.count

    expect { import("title,category,feed_url\n\"unterminated") }
      .to raise_error(described_class::FileError, /malformed/)
    expect(Feed.count).to eq(original_count)
  end

  it 'rejects files containing more than 500 data rows' do
    rows = Array.new(501) { |index| "Feed #{index},Research,https://example.com/#{index}.xml" }
    csv = ([ 'title,category,feed_url' ] + rows).join("\n")

    expect { import(csv) }
      .to raise_error(described_class::FileError, 'CSV contains more than 500 rows')
  end

  it 'reports blank fields without validating or importing the row' do
    result = import("title,category,feed_url\n,Research,\n")

    expect(result.imported).to be_empty
    expect(result.unimported.first['reason']).to include('title', 'feed_url')
    expect(validator).not_to have_received(:validate!)
  end

  it 'reports existing feed URLs without updating them' do
    existing = create(:feed, title: 'Existing', feed_url: 'https://example.com/news.xml')

    result = import("title,category,feed_url\nReplacement,Research,https://example.com/news.xml\n")

    expect(result.unimported.first['reason']).to eq('Feed URL already exists')
    expect(existing.reload.title).to eq('Existing')
  end

  it 'does not create a category for an invalid or empty feed and continues later rows' do
    allow(validator).to receive(:validate!).with('https://example.com/empty.xml')
      .and_raise(Feeds::FeedContentValidator::ValidationError, 'Feed contains no entries')

    csv = <<~CSV
      title,category,feed_url
      Empty,Unused,https://example.com/empty.xml
      Valid,Research,https://example.com/valid.xml
    CSV
    result = import(csv)

    expect(result.unimported.first['reason']).to eq('Feed contains no entries')
    expect(result.imported.map { |row| row['title'] }).to eq([ 'Valid' ])
    expect(FeedCategory.exists?(name: 'Unused')).to be false
    expect(FeedCategory.exists?(name: 'Research')).to be true
  end
end
