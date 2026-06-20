class Tag < ApplicationRecord
  has_many :inboxes, dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Returns Tailwind badge classes for the tag's color, falling back to neutral gray.
  def badge_classes
    color.presence || "bg-gray-100 text-gray-700"
  end
end
