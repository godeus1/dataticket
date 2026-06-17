FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Account #{n}" }
    sequence(:slug) { |n| "account-#{n}" }
    plan   { "standard" }
    active { true }
  end
end
