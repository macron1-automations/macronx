class Workflows::RunJob < ApplicationJob
  queue_as :default

  def perform(inbox_id)
    inbox = Inbox.find_by(id: inbox_id)
    return if inbox.nil?

    Workflows::Runner.new(inbox).call
  end
end
