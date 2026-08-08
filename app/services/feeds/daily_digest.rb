require "rss"

module Feeds
  class DailyDigest
    Result = Data.define(:inbox, :stats, :errors)

    DEFAULT_ITEM_LIMIT = 10
    SUMMARY_LENGTH = 200

    def initialize(user:, fetcher: RssFetcher.new, item_limit: DEFAULT_ITEM_LIMIT, date: Time.current)
      @user = user
      @fetcher = fetcher
      @item_limit = item_limit
      @date = date
    end

    def call
      errors = []
      categories = {}
      feeds_processed = 0
      items_collected = 0

      user.feeds.includes(:feed_category).order(:title).each do |feed|
        begin
          items = today_items(fetcher.fetch(feed.feed_url))
          next if items.empty?

          categories[feed.feed_category.name] ||= []
          categories[feed.feed_category.name] << { "feed" => feed.title, "items" => items }
          feeds_processed += 1
          items_collected += items.size
        rescue RssFetcher::FetchError => error
          errors << { "feed" => feed.title, "url" => feed.feed_url, "error" => error.message }
        end
      end

      inbox = create_inbox(categories, errors, feeds_processed, items_collected) if categories.any?
      Result.new(
        inbox: inbox,
        stats: {
          categories: categories.size,
          feeds_processed: feeds_processed,
          items_collected: items_collected
        },
        errors: errors
      )
    end

    private

    attr_reader :user, :fetcher, :item_limit, :date

    def today_items(document)
      entries = document.respond_to?(:items) ? document.items : document.entries
      entries.filter_map do |entry|
        next unless published_today?(entry)

        {
          "title" => entry_title(entry),
          "summary" => summarize(entry),
          "link" => entry_link(entry),
          "published_at" => published_at_for(entry).iso8601
        }
      end.first(item_limit)
    end

    def published_today?(entry)
      published_at = published_at_for(entry)
      published_at && published_at >= date.beginning_of_day && published_at <= date.end_of_day
    end

    def published_at_for(entry)
      value =
        if entry.respond_to?(:pubDate)
          entry.pubDate
        elsif entry.respond_to?(:published)
          entry.published
        elsif entry.respond_to?(:updated)
          entry.updated
        end
      value.respond_to?(:content) ? value.content : value
    end

    def entry_title(entry)
      title = entry.title if entry.respond_to?(:title)
      title = title.content if title.respond_to?(:content)
      title.to_s.strip
    end

    def entry_link(entry)
      link = entry.link if entry.respond_to?(:link)
      return nil if link.blank?

      link.is_a?(String) ? link : Array(link).filter_map { |element| element.href if element.respond_to?(:href) }.first
    end

    def summarize(entry)
      raw = raw_summary(entry)
      plain = ActionController::Base.helpers.strip_tags(raw.to_s).gsub(/\s+/, " ").strip
      plain.truncate(SUMMARY_LENGTH, separator: " ")
    end

    def raw_summary(entry)
      candidates = []
      candidates << entry.content_encoded if entry.respond_to?(:content_encoded)
      candidates << entry.description if entry.respond_to?(:description)
      candidates << entry.summary if entry.respond_to?(:summary)
      candidates << entry.content if entry.respond_to?(:content)

      text = candidates.compact.find { |candidate| candidate.present? }
      text.respond_to?(:content) ? text.content : text
    end

    def create_inbox(categories, errors, feeds_processed, items_collected)
      user.inboxes.create!(
        name: "Daily feed digest — #{date.to_date.iso8601}",
        source: "feed-digest",
        summary: "#{categories.size} categor#{categories.size == 1 ? 'y' : 'ies'}, " \
                 "#{feeds_processed} feed#{feeds_processed == 1 ? '' : 's'}, " \
                 "#{items_collected} article#{items_collected == 1 ? '' : 's'}",
        payload: categories,
        metadata: {
          "run_at" => date.iso8601,
          "feeds_processed" => feeds_processed,
          "items_collected" => items_collected,
          "errors" => errors
        }
      )
    end
  end
end
