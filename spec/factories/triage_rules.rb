FactoryBot.define do
  factory :triage_rule do
    organization
    sequence(:name)    { |n| "Regra #{n}" }
    sequence(:keyword) { |n| "keyword#{n}" }
    position { 0 }
    active   { true }
  end
end
