class FeedImport < ApplicationRecord
  MAX_FILE_SIZE = 1.megabyte

  belongs_to :user
  has_one_attached :csv_file

  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, default: :pending, validate: true

  validates :source_filename, presence: true
  validate :csv_file_is_attached
  validate :csv_file_is_csv
  validate :csv_file_is_within_size_limit

  def imported_count
    imported_rows.size
  end

  def unimported_count
    unimported_rows.size
  end

  private

  def csv_file_is_attached
    errors.add(:csv_file, "is required") if pending? && !csv_file.attached?
  end

  def csv_file_is_csv
    return unless csv_file.attached?
    return if csv_file.filename.extension_without_delimiter.casecmp?("csv")

    errors.add(:csv_file, "must be a CSV file")
  end

  def csv_file_is_within_size_limit
    return unless csv_file.attached?
    return if csv_file.blob.byte_size <= MAX_FILE_SIZE

    errors.add(:csv_file, "must be 1 MB or smaller")
  end
end
