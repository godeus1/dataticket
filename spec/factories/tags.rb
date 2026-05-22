FactoryBot.define do
  factory :tag do
    organization
    sequence(:name) { |n| "tag#{n}" }
    color { "#2383e2" }
  end
end
