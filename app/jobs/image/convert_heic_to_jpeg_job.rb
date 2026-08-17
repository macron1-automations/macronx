module Image
  class ConvertHeicToJpegJob < ApplicationJob
    queue_as :default

    HEIC_CONTENT_TYPES = %w[
      image/heic
      image/heif
      image/x-heic
      image/x-heif
    ].freeze

    def perform(inbox_id)
      inbox = Inbox.find_by(id: inbox_id)
      return if inbox.nil?

      convert_heic_attachments(inbox)
      enqueue_workflow(inbox)
    end

    private

    def convert_heic_attachments(inbox)
      heic_attachments = inbox.attachments.select { |a| heic?(a) }
      return if heic_attachments.empty?

      heic_attachments.each { |attachment| convert_to_jpeg(inbox, attachment) }
    end

    def convert_to_jpeg(inbox, attachment)
      input_path = download_to_tempfile(attachment)
      output_path = Tempfile.new([ "converted", ".jpg" ])

      image = MiniMagick::Image.new(input_path.path)
      image.format("jpg")
      image.quality(100)
      image.write(output_path.path)

      jpeg_filename = File.basename(attachment.filename.to_s, File.extname(attachment.filename.to_s)) + ".jpg"

      attachment.purge

      File.open(output_path.path, "rb") do |io|
        inbox.attachments.attach(
          io: io,
          filename: jpeg_filename,
          content_type: "image/jpeg"
        )
      end
    ensure
      input_path&.close!
      input_path&.unlink
      output_path&.close!
      output_path&.unlink
    end

    def download_to_tempfile(attachment)
      tempfile = Tempfile.new([ "heic_input", File.extname(attachment.filename.to_s) ])
      tempfile.binmode
      tempfile.write(attachment.download)
      tempfile.rewind
      tempfile
    end

    def heic?(attachment)
      HEIC_CONTENT_TYPES.include?(attachment.content_type)
    end

    def enqueue_workflow(inbox)
      return if inbox.tag.blank?
      return unless Workflow.exists?(tag_id: inbox.tag_id)

      Workflows::RunJob.perform_later(inbox.id)
    end
  end
end
