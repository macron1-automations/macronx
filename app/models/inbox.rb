class Inbox < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :workflow, optional: true
  belongs_to :tag, optional: true

  has_many_attached :attachments

  attr_accessor :payload_text, :metadata_text

  before_validation :set_default_name
  before_validation :parse_json_fields
  after_create_commit :enqueue_processing

  validates :workflow_id, presence: true, if: :processed?

  scope :unprocessed, -> { where(processed: false, archived: false) }
  scope :processed_items, -> { where(processed: true, archived: false) }
  scope :archived, -> { where(archived: true) }

  def actionable_workflow
    return nil if tag_id.blank?

    Workflow.find_by(tag_id: tag_id)
  end

  def can_process?
    actionable_workflow.present?
  end

  private

  def enqueue_processing
    return unless can_process?

    Inboxes::ProcessJob.perform_later(id)
  end

  # TODO: replace with LLM-generated name derived from payload/summary
  def set_default_name
    self.name = "inbox-#{SecureRandom.hex(4)}" if name.blank?
  end

  def parse_json_fields
    self.payload  = JSON.parse(payload_text)  if payload_text.present?
    self.metadata = JSON.parse(metadata_text) if metadata_text.present?
  rescue JSON::ParserError => e
    errors.add(:base, "Invalid JSON: #{e.message}")
    throw :abort
  end
end
