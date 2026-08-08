class Feed < ApplicationRecord
  belongs_to :feed_category
  belongs_to :user

  validates :title, presence: true
  validates :feed_url, presence: true, uniqueness: true
end
