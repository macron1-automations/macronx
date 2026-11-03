class Feeds::DailyDigestJob < ApplicationJob
  queue_as :default

  def perform(user = nil)
    user = User.find_by(id: user) if user.is_a?(Integer) || user.is_a?(String)

    if user
      Feeds::DailyDigest.new(user: user).call
    else
      User.joins(:feeds).distinct.find_each do |u|
        Feeds::DailyDigest.new(user: u).call
      end
    end
  end
end
