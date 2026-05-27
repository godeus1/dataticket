class SlaPolicy < ApplicationRecord
  belongs_to :organization
  belongs_to :priority, optional: true
  belongs_to :category, optional: true

  validates :response_hours, :resolve_hours,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  validate :must_have_at_least_one_dimension

  scope :active, -> { where(active: true) }

  # Bust cache whenever uma política é criada, atualizada ou destruída.
  # Estratégia de versão: deletar a chave de versão da org invalida todas as
  # entradas do cache sem precisar de delete_matched (incompatível com Redis).
  after_commit :bust_sla_cache

  # Most specific policy wins: category+priority > priority-only > category-only
  # Resultado cacheado por organização + combinação priority/category.
  # Cache é invalidado automaticamente via after_commit quando políticas mudam.
  def self.find_for(organization:, priority:, category:)
    version   = sla_cache_version(organization.id)
    cache_key = "sla/#{organization.id}/v#{version}/#{priority&.id}/#{category&.id}"

    Rails.cache.fetch(cache_key, expires_in: 2.hours) do
      base  = where(organization: organization).active

      exact = base.find_by(priority: priority, category: category)
      next exact if exact

      if priority
        by_priority = base.find_by(priority: priority, category: nil)
        next by_priority if by_priority
      end

      if category
        by_category = base.find_by(priority: nil, category: category)
        next by_category if by_category
      end

      nil
    end
  end

  def self.sla_cache_version(org_id)
    Rails.cache.fetch("sla_version/#{org_id}", expires_in: 24.hours) { SecureRandom.hex(4) }
  end

  private

  # Apaga a chave de versão — na próxima chamada find_for uma nova versão é gerada,
  # tornando todas as entradas antigas efetivamente obsoletas (expiram via TTL).
  def bust_sla_cache
    Rails.cache.delete("sla_version/#{organization_id}")
  end

  def must_have_at_least_one_dimension
    if priority_id.nil? && category_id.nil?
      errors.add(:base, "precisa ter pelo menos uma prioridade ou categoria")
    end
  end
end
