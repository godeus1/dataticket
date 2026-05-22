FactoryBot.define do
  factory :category do
    organization
    sequence(:name) { |n| "Category #{n}" }
    color           { "#2383e2" }
    active          { true }
  end
end
