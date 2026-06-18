# Popula uma empresa nova com dados mínimos para ser utilizável de imediato:
# prioridades padrão (necessárias para triagem) e uma categoria geral.
# Idempotente: não duplica se a empresa já tiver prioridades/categoria.
class OrganizationSeeder
  DEFAULT_PRIORITIES = [
    { name: "Baixa",   sla_hours: 72, sla_days: 5, position: 1, color: "#6b7280" },
    { name: "Média",   sla_hours: 48, sla_days: 3, position: 2, color: "#2383e2" },
    { name: "Alta",    sla_hours: 24, sla_days: 1, position: 3, color: "#d97706" },
    { name: "Crítica", sla_hours: 4,  sla_days: 1, position: 4, color: "#dc2626" },
  ].freeze

  def initialize(organization)
    @org = organization
  end

  def call
    seed_priorities
    seed_category
    @org
  end

  private

  def seed_priorities
    return if @org.priorities.exists?

    DEFAULT_PRIORITIES.each { |attrs| @org.priorities.create!(attrs) }
  end

  def seed_category
    return if @org.categories.exists?

    @org.categories.create!(name: "Geral", color: "#2383e2", active: true)
  end
end
