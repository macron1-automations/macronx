class FeedImportJob < ApplicationJob
  queue_as :default

  def perform(feed_import_id)
    feed_import = FeedImport.find(feed_import_id)
    return unless feed_import.pending?

    feed_import.update!(status: :processing, started_at: Time.current, error_message: nil)
    result = Feeds::ImportFromCsv.new(feed_import.csv_file.download).call
    feed_import.update!(
      status: :completed,
      imported_rows: result.imported,
      unimported_rows: result.unimported,
      completed_at: Time.current
    )
  rescue StandardError => error
    feed_import&.update(
      status: :failed,
      error_message: error.message,
      completed_at: Time.current
    )
  ensure
    feed_import&.csv_file&.purge if feed_import&.csv_file&.attached?
  end
end
