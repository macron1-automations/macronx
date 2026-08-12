class Workflow < ApplicationRecord
  has_many :inboxes
  belongs_to :tag, optional: true

  validates :name, presence: true
  validates :prompt, presence: true
  validates :tag_id, uniqueness: true, allow_nil: true
end
