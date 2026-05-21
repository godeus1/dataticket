FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    sequence(:slug) { |n| "org-#{n}" }
    timezone    { "America/Sao_Paulo" }
    date_format { "DD/MM/YYYY" }
  end
end
