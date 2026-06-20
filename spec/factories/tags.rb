FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "Tag #{n}" }
    color { nil }
  end
end
