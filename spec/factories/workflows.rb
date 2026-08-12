FactoryBot.define do
  factory :workflow do
    sequence(:name) { |n| "Workflow #{n}" }
    prompt { "You are an analyst. Analyze the payload:\n\n{{payload}}" }
    association :tag
  end
end
