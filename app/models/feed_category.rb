class FeedCategory < ApplicationRecord
  has_many :feeds, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
