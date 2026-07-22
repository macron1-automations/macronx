FactoryBot.define do
  factory :workflow do
    sequence(:name) { |n| "Workflow #{n}" }
  end
end
