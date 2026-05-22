FactoryBot.define do
  factory :webhook_endpoint do
    organization
    sequence(:name) { |n| "Webhook #{n}" }
    url    { "https://hooks.example.com/#{SecureRandom.hex(4)}" }
    events { [ "ticket.created" ] }
    active { true }
  end
end
