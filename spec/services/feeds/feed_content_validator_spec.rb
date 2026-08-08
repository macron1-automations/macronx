require 'rails_helper'

RSpec.describe Feeds::FeedContentValidator do
  subject(:validator) { described_class.new(fetcher: fetcher) }

  let(:fetcher) { instance_double(Feeds::RssFetcher) }

  let(:rss_with_entry) do
    RSS::Parser.parse(<<~XML, false)
      <?xml version="1.0"?>
      <rss version="2.0"><channel><title>News</title><link>https://example.com</link><description>News</description>
      <item><title>Entry</title><link>https://example.com/entry</link></item></channel></rss>
    XML
  end

  let(:atom_with_entry) do
    RSS::Parser.parse(<<~XML, false)
      <?xml version="1.0"?>
      <feed xmlns="http://www.w3.org/2005/Atom"><title>News</title><id>https://example.com</id><updated>2026-07-22T00:00:00Z</updated>
      <entry><title>Entry</title><id>entry-1</id><updated>2026-07-22T00:00:00Z</updated></entry></feed>
    XML
  end

  def stub_document(document)
    allow(fetcher).to receive(:fetch).with('https://example.com/feed').and_return(document)
  end

  it 'accepts RSS with at least one item' do
    stub_document(rss_with_entry)

    expect(validator.validate!('https://example.com/feed')).to be true
  end

  it 'accepts Atom with at least one entry' do
    stub_document(atom_with_entry)

    expect(validator.validate!('https://example.com/feed')).to be true
  end

  it 'rejects an empty feed' do
    document = RSS::Parser.parse(<<~XML, false)
      <rss version="2.0"><channel><title>Empty</title><link>https://example.com</link><description>Empty</description></channel></rss>
    XML
    stub_document(document)

    expect { validator.validate!('https://example.com/feed') }
      .to raise_error(described_class::ValidationError, 'Feed contains no entries')
  end

  it 'rejects malformed feed content' do
    allow(fetcher).to receive(:fetch)
      .and_raise(Feeds::RssFetcher::FetchError, 'Response is not a valid RSS or Atom feed: not well-formed')

    expect { validator.validate!('https://example.com/feed') }
      .to raise_error(described_class::ValidationError, /not a valid RSS or Atom feed/)
  end

  it 'surfaces other fetch failures as validation errors' do
    allow(fetcher).to receive(:fetch).and_raise(Feeds::RssFetcher::FetchError, 'Feed returned HTTP 404')

    expect { validator.validate!('https://example.com/feed') }
      .to raise_error(described_class::ValidationError, 'Feed returned HTTP 404')
  end
end
