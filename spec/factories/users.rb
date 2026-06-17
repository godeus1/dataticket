FactoryBot.define do
  factory :user do
    organization
    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }
    email      { Faker::Internet.unique.email }
    password   { "Password123!" }
    role       { "user" }
    active     { true }

    trait :admin do
      role { "admin" }
    end

    trait :analyst do
      role { "analyst" }
    end

    trait :manager do
      role { "manager" }
    end

    trait :msp_admin do
      role { "msp_admin" }
    end
  end
end
