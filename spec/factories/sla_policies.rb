FactoryBot.define do
  factory :sla_policy do
    organization
    priority
    response_hours { 2 }
    resolve_hours  { 8 }
    active         { true }
  end
end
