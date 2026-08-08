require "rss"

module Feeds
  class FeedContentValidator
    class ValidationError < StandardError; end

    MAX_RESPONSE_SIZE = RssFetcher::MAX_RESPONSE_SIZE

    def initialize(fetcher: RssFetcher.new)
      @fetcher = fetcher
    end

    def validate!(url)
      document = fetcher.fetch(url)
      entries = document.respond_to?(:items) ? document.items : document.entries
      raise ValidationError, "Feed contains no entries" if entries.blank?

      true
    rescue RssFetcher::FetchError => error
      raise ValidationError, error.message
    end

    private

    attr_reader :fetcher
  end
end
