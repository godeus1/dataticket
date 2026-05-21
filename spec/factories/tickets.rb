FactoryBot.define do
  factory :ticket do
    organization
    requester { association :user, organization: organization }
    title     { Faker::Lorem.sentence(word_count: 4) }
    status    { "Não iniciado" }

    trait :in_progress do
      status { "Em andamento" }
    end

    trait :resolved do
      status     { "Resolvido" }
      resolved_at { Time.current }
    end

    trait :overdue do
      status   { "Em andamento" }
      deadline { 1.day.ago }
    end
  end
end
