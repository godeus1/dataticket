FactoryBot.define do
  factory :custom_field do
    organization
    sequence(:name) { |n| "Campo #{n}" }
    field_type { "text" }
    required   { false }
    position   { 0 }
    active     { true }
    options    { [] }

    trait :dropdown do
      field_type { "dropdown" }
      options    { [ "Opção A", "Opção B", "Opção C" ] }
    end

    trait :required do
      required { true }
    end
  end
end
