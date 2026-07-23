require "csv"
require "set"

module Feeds
  class ImportFromCsv
    class FileError < StandardError; end

    Result = Data.define(:imported, :unimported)
    REQUIRED_HEADERS = %w[title category feed_url].freeze
    MAX_ROWS = 500

    def initialize(contents, validator: FeedContentValidator.new)
      @contents = contents
      @validator = validator
    end

    def call
      rows = parsed_rows
      existing_urls = Feed.where(feed_url: rows.filter_map { |row| row["feed_url"]&.strip }).pluck(:feed_url).to_set
      imported = []
      unimported = []

      rows.each_with_index do |row, index|
        attributes = normalized_attributes(row, index + 2)
        missing_fields = REQUIRED_HEADERS.select { |header| attributes[header].blank? }

        if missing_fields.any?
          unimported << attributes.merge("reason" => "Missing required field(s): #{missing_fields.join(', ')}")
          next
        end

        if existing_urls.include?(attributes["feed_url"])
          unimported << attributes.merge("reason" => "Feed URL already exists")
          next
        end

        begin
          validator.validate!(attributes["feed_url"])
          feed, category_created = create_feed(attributes)
          existing_urls.add(feed.feed_url)
          imported << attributes.merge(
            "feed_id" => feed.id,
            "category_status" => category_created ? "created" : "reused"
          )
        rescue FeedContentValidator::ValidationError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
          unimported << attributes.merge("reason" => error.message)
        end
      end

      Result.new(imported:, unimported:)
    end

    private

    attr_reader :contents, :validator

    def parsed_rows
      data = contents.to_s.dup.force_encoding(Encoding::UTF_8)
      raise FileError, "CSV must be valid UTF-8" unless data.valid_encoding?

      table = CSV.parse(data.delete_prefix("\uFEFF"), headers: true)
      headers = table.headers.compact.map(&:strip)
      missing_headers = REQUIRED_HEADERS - headers
      raise FileError, "CSV is missing required header(s): #{missing_headers.join(', ')}" if missing_headers.any?
      raise FileError, "CSV contains more than #{MAX_ROWS} rows" if table.size > MAX_ROWS

      table.map { |row| row.to_h.transform_keys { |header| header&.strip } }
    rescue CSV::MalformedCSVError => error
      raise FileError, "CSV is malformed: #{error.message}"
    end

    def normalized_attributes(row, row_number)
      {
        "row" => row_number,
        "title" => row["title"]&.strip,
        "category" => row["category"]&.strip,
        "feed_url" => row["feed_url"]&.strip
      }
    end

    def create_feed(attributes)
      category_created = false
      feed = nil

      Feed.transaction do
        category = find_category(attributes["category"])
        unless category
          begin
            FeedCategory.transaction(requires_new: true) do
              category = FeedCategory.create!(name: attributes["category"])
              category_created = true
            end
          rescue ActiveRecord::RecordNotUnique
            category = find_category(attributes["category"])
          end
        end

        feed = Feed.create!(
          title: attributes["title"],
          feed_url: attributes["feed_url"],
          feed_category: category
        )
      end

      [ feed, category_created ]
    end

    def find_category(name)
      FeedCategory.where("LOWER(name) = ?", name.downcase).first
    end
  end
end
