class Feeds::DailyDigestJob < ApplicationJob
  queue_as :default

  def perform
    User.joins(:feeds).distinct.find_each do |user|
      Feeds::DailyDigest.new(user: user).call
    end
  end
end
