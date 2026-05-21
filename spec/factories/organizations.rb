FactoryBot.define do
  factory :organization do
    name { "Salvabras" }
    slug { "salvabras" }
    timezone   { "America/Sao_Paulo" }
    date_format { "DD/MM/YYYY" }
  end
end
