FactoryBot.define do
  factory :holiday do
    organization
    sequence(:name) { |n| "Feriado #{n}" }
    date { Date.today + 30.days }
  end
end
