class ScheduledDay < ApplicationRecord
  belongs_to :ticket, foreign_key: :ticket_id
  belongs_to :user

  validates :date,  presence: true
  validates :hours, numericality: { greater_than: 0, less_than_or_equal_to: 24 }

  # Invalida o cache de capacidade da org sempre que a agenda muda.
  # Estratégia de versão: apagar a chave gera nova versão na próxima leitura,
  # tornando todas as entradas anteriores efetivamente obsoletas.
  after_commit :bust_capacity_cache

  private

  def bust_capacity_cache
    org_id = ticket&.organization_id
    Rails.cache.delete("capacity_version/#{org_id}") if org_id
  end
end
