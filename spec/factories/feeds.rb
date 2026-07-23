FactoryBot.define do
  factory :feed do
    sequence(:title) { |n| "Feed #{n}" }
    sequence(:feed_url) { |n| "https://example.com/feeds/#{n}.xml" }
    feed_category
  end
end
