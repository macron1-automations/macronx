module Workflows
  class Reprocessor
    Result = Data.define(:count, :reprocessed, :skipped, :errors)

    def initialize(tag_name:, limit:, stream: nil)
      @tag_name = tag_name
      @limit = limit
      @stream = stream
    end

    def call
      tag = Tag.find_by(name: tag_name)
      return Result.new(count: 0, reprocessed: [], skipped: [], errors: []) if tag.nil?

      inboxes = Inbox.processed_items.where(tag_id: tag.id).order(created_at: :desc).limit(limit)

      reprocessed = []
      skipped = []
      errors = []

      inboxes.each do |inbox|
        result = Workflows::Runner.new(inbox).call
        if result.response
          reprocessed << inbox
          stream&.puts("  -> inbox ##{inbox.id} body updated")
        else
          skipped << inbox
          stream&.puts("  -  inbox ##{inbox.id} skipped (no workflow)")
        end
      rescue StandardError => error
        errors << { inbox_id: inbox.id, error: error.message }
        stream&.puts("  x  inbox ##{inbox.id} failed: #{error.message}")
      end

      Result.new(count: inboxes.size, reprocessed: reprocessed, skipped: skipped, errors: errors)
    end

    private

    attr_reader :tag_name, :limit, :stream
  end
end
