module Audio
  class ConvertM4aToMp3Job < ApplicationJob
    queue_as :default

    M4A_CONTENT_TYPES = %w[
      audio/mp4
      audio/x-m4a
      audio/m4a
    ].freeze

    def perform(inbox_id)
      inbox = Inbox.find_by(id: inbox_id)
      return if inbox.nil?

      convert_m4a_attachments(inbox)
      transcribe_audio(inbox)
      enqueue_workflow(inbox)
    end

    private

    def convert_m4a_attachments(inbox)
      m4a_attachments = inbox.attachments.select { |a| m4a?(a) }
      return if m4a_attachments.empty?

      m4a_attachments.each { |attachment| convert_to_mp3(inbox, attachment) }
    end

    def transcribe_audio(inbox)
      audio = inbox.attachments.detect { |a| a.content_type&.start_with?("audio/") }
      return if audio.nil?

      tmpfile = write_to_tempfile(audio)
      transcription = RubyLLM.transcribe(tmpfile.path)
      return if transcription.text.blank?

      inbox.update_column(:metadata, (inbox.metadata || {}).merge("audio_transcript" => transcription.text))
    ensure
      tmpfile&.close!
    end

    def convert_to_mp3(inbox, attachment)
      input_path = download_to_tempfile(attachment)
      output_path = Tempfile.new([ "converted", ".mp3" ])

      success = system("ffmpeg", "-i", input_path.path, "-codec:a", "libmp3lame", "-q:a", "2", output_path.path, "-y", "-loglevel", "error")

      unless success
        raise "ffmpeg conversion failed for #{attachment.filename}"
      end

      mp3_filename = File.basename(attachment.filename.to_s, File.extname(attachment.filename.to_s)) + ".mp3"

      attachment.purge

      File.open(output_path.path, "rb") do |io|
        inbox.attachments.attach(
          io: io,
          filename: mp3_filename,
          content_type: "audio/mpeg"
        )
      end
    ensure
      input_path&.close!
      output_path&.close!
      output_path&.unlink
    end

    def download_to_tempfile(attachment)
      tempfile = Tempfile.new([ "m4a_input", File.extname(attachment.filename.to_s) ])
      tempfile.binmode
      tempfile.write(attachment.download)
      tempfile.rewind
      tempfile
    end

    def write_to_tempfile(attachment)
      tempfile = Tempfile.new([ attachment.filename.to_s, File.extname(attachment.filename.to_s) ])
      tempfile.binmode
      tempfile.write(attachment.download)
      tempfile.rewind
      tempfile
    end

    def m4a?(attachment)
      M4A_CONTENT_TYPES.include?(attachment.content_type)
    end

    def enqueue_workflow(inbox)
      return if inbox.tag.blank?
      return unless Workflow.exists?(tag_id: inbox.tag_id)

      Workflows::RunJob.perform_later(inbox.id)
    end
  end
end
