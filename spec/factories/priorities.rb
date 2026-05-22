FactoryBot.define do
  factory :priority do
    organization
    sequence(:name) { |n| "Priority #{n}" }
    color           { "#6b7280" }
    sla_hours       { 48 }
    active          { true }
    position        { 1 }
  end
end
