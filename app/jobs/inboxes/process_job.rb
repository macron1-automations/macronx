module Inboxes
  class ProcessJob < ApplicationJob
    queue_as :default

    def perform(inbox_id)
      inbox = Inbox.find_by(id: inbox_id)
      return if inbox.nil?

      Audio::ConvertM4aToMp3Job.perform_now(inbox.id)
      Image::ConvertHeicToJpegJob.perform_now(inbox.id)

      Workflows::RunJob.perform_later(inbox.id)
    end
  end
end
