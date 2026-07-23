FactoryBot.define do
  factory :feed_category do
    sequence(:name) { |n| "Feed category #{n}" }
  end
end
