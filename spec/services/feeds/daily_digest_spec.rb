require 'rails_helper'

RSpec.describe Feeds::DailyDigest do
  let(:user) { create(:user) }
  let(:fetcher) { instance_double(Feeds::RssFetcher) }
  let(:date) { Time.current }

  def build_rss(items)
    item_xml = items.map do |item|
      <<~XML
        <item>
          <title>#{item[:title]}</title>
          <link>#{item[:link]}</link>
          <description><![CDATA[#{item[:description]}]]></description>
          <pubDate>#{item[:published_at].rfc2822}</pubDate>
        </item>
      XML
    end.join

    RSS::Parser.parse(<<~XML, false)
      <?xml version="1.0"?>
      <rss version="2.0"><channel><title>News</title><link>https://example.com</link><description>News</description>
      #{item_xml}</channel></rss>
    XML
  end

  def build_atom(entries)
    entry_xml = entries.map do |entry|
      <<~XML
        <entry>
          <title>#{entry[:title]}</title>
          <id>#{entry[:link]}</id>
          <link href="#{entry[:link]}"/>
          <summary><![CDATA[#{entry[:summary]}]]></summary>
          <published>#{entry[:published_at].iso8601}</published>
          <updated>#{entry[:published_at].iso8601}</updated>
        </entry>
      XML
    end.join

    RSS::Parser.parse(<<~XML, false)
      <?xml version="1.0"?>
      <feed xmlns="http://www.w3.org/2005/Atom"><title>News</title><id>https://example.com</id><updated>#{date.iso8601}</updated>
      #{entry_xml}</feed>
    XML
  end

  def call_digest
    described_class.new(user: user, fetcher: fetcher, date: date).call
  end

  describe 'building the daily digest' do
    it 'creates one inbox item keyed by category with today\'s articles' do
      category = create(:feed_category, name: 'Technology')
      feed = create(:feed, title: 'Tech News', feed_category: category, user: user)
      document = build_rss([
        { title: 'Post A', link: 'https://example.com/a', description: 'First story', published_at: date.midday },
        { title: 'Post B', link: 'https://example.com/b', description: 'Second story', published_at: date.midday }
      ])
      allow(fetcher).to receive(:fetch).with(feed.feed_url).and_return(document)

      result = call_digest

      inbox = result.inbox
      expect(inbox.user).to eq(user)
      expect(inbox.source).to eq('feed-digest')
      expect(inbox.name).to include(date.to_date.iso8601)

      payload = inbox.payload
      expect(payload).to have_key('Technology')
      expect(payload['Technology'].first['feed']).to eq('Tech News')
      expect(payload['Technology'].first['items'].map { |item| item['title'] }).to eq([ 'Post A', 'Post B' ])
      expect(payload['Technology'].first['items'].first).to include(
        'summary' => 'First story',
        'link' => 'https://example.com/a'
      )
      expect(result.stats).to eq(categories: 1, feeds_processed: 1, items_collected: 2)
      expect(result.errors).to be_empty
    end

    it 'groups multiple feeds under the same category' do
      category = create(:feed_category, name: 'Technology')
      feed_a = create(:feed, title: 'Feed A', feed_category: category, user: user)
      feed_b = create(:feed, title: 'Feed B', feed_category: category, user: user)
      allow(fetcher).to receive(:fetch).with(feed_a.feed_url)
        .and_return(build_rss([ { title: 'A1', link: 'https://example.com/a1', description: 'x', published_at: date.midday } ]))
      allow(fetcher).to receive(:fetch).with(feed_b.feed_url)
        .and_return(build_rss([ { title: 'B1', link: 'https://example.com/b1', description: 'y', published_at: date.midday } ]))

      result = call_digest

      expect(result.inbox.payload['Technology'].map { |entry| entry['feed'] }).to eq([ 'Feed A', 'Feed B' ])
    end

    it 'only includes articles published today' do
      category = create(:feed_category, name: 'Technology')
      feed = create(:feed, title: 'Tech News', feed_category: category, user: user)
      document = build_rss([
        { title: 'Today Post', link: 'https://example.com/today', description: 'x', published_at: date.midday },
        { title: 'Old Post', link: 'https://example.com/old', description: 'y', published_at: date.yesterday.midday }
      ])
      allow(fetcher).to receive(:fetch).with(feed.feed_url).and_return(document)

      items = call_digest.inbox.payload['Technology'].first['items']

      expect(items.map { |item| item['title'] }).to eq([ 'Today Post' ])
    end

    it 'caps the number of articles per feed at ten' do
      category = create(:feed_category, name: 'Technology')
      feed = create(:feed, title: 'Tech News', feed_category: category, user: user)
      items = Array.new(12) do |index|
        { title: "Post #{index}", link: "https://example.com/#{index}", description: 'x', published_at: date.midday }
      end
      allow(fetcher).to receive(:fetch).with(feed.feed_url).and_return(build_rss(items))

      result = call_digest

      expect(result.inbox.payload['Technology'].first['items'].size).to eq(10)
      expect(result.stats[:items_collected]).to eq(10)
    end

    it 'skips feeds with no articles published today' do
      category = create(:feed_category, name: 'Technology')
      feed = create(:feed, title: 'Quiet Feed', feed_category: category, user: user)
      allow(fetcher).to receive(:fetch).with(feed.feed_url)
        .and_return(build_rss([ { title: 'Old', link: 'https://example.com/old', description: 'x', published_at: date.yesterday.midday } ]))

      result = call_digest

      expect(result.inbox).to be_nil
      expect(result.stats).to eq(categories: 0, feeds_processed: 0, items_collected: 0)
    end

    it 'strips HTML and truncates long summaries' do
      category = create(:feed_category, name: 'Technology')
      feed = create(:feed, title: 'Tech News', feed_category: category, user: user)
      long_text = '<p>Some <b>HTML</b></p> ' + ('word ' * 100)
      allow(fetcher).to receive(:fetch).with(feed.feed_url)
        .and_return(build_rss([ { title: 'Post', link: 'https://example.com/a', description: long_text, published_at: date.midday } ]))

      summary = call_digest.inbox.payload['Technology'].first['items'].first['summary']

      expect(summary).to start_with('Some HTML word')
      expect(summary).not_to include('<')
      expect(summary.length).to be <= 200
    end

    it 'parses Atom feeds' do
      category = create(:feed_category, name: 'Technology')
      feed = create(:feed, title: 'Atom Feed', feed_category: category, user: user)
      document = build_atom([ { title: 'Atom Post', link: 'https://example.com/atom', summary: 'From Atom', published_at: date.midday } ])
      allow(fetcher).to receive(:fetch).with(feed.feed_url).and_return(document)

      items = call_digest.inbox.payload['Technology'].first['items']

      expect(items.first['title']).to eq('Atom Post')
      expect(items.first['summary']).to eq('From Atom')
    end

    it 'continues past failed feeds and records their errors' do
      category = create(:feed_category, name: 'Technology')
      good_feed = create(:feed, title: 'Good Feed', feed_category: category, user: user)
      bad_feed = create(:feed, title: 'Bad Feed', feed_category: category, user: user)
      allow(fetcher).to receive(:fetch).with(good_feed.feed_url)
        .and_return(build_rss([ { title: 'Post', link: 'https://example.com/a', description: 'x', published_at: date.midday } ]))
      allow(fetcher).to receive(:fetch).with(bad_feed.feed_url)
        .and_raise(Feeds::RssFetcher::FetchError, 'Feed returned HTTP 500')

      result = call_digest

      expect(result.inbox.payload['Technology'].map { |entry| entry['feed'] }).to eq([ 'Good Feed' ])
      expect(result.errors).to eq([
        { 'feed' => 'Bad Feed', 'url' => bad_feed.feed_url, 'error' => 'Feed returned HTTP 500' }
      ])
      expect(result.inbox.metadata['errors']).to eq(result.errors)
    end
  end
end
