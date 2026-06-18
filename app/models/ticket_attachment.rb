class TicketAttachment < ApplicationRecord
  belongs_to :ticket, foreign_key: :ticket_id
  belongs_to :user
  belongs_to :deleted_by, class_name: "User", optional: true

  validates :filename, presence: true

  # Janela de restauração após mover para a lixeira.
  RESTORE_WINDOW = 30.days

  scope :active,  -> { where(deleted_at: nil) }
  scope :trashed, -> { where.not(deleted_at: nil) }

  def deleted?
    deleted_at.present?
  end

  # Move para a lixeira (soft delete). O arquivo NÃO é removido — fica disponível
  # para restauração até a purga definitiva (30 dias).
  def soft_delete!(actor)
    update!(deleted_at: Time.current, deleted_by: actor)
  end

  # Restaura da lixeira para o ticket.
  def restore!
    update!(deleted_at: nil, deleted_by: nil)
  end

  # Momento em que o anexo deixa de ser restaurável (purga definitiva).
  def restorable_until
    deleted_at && (deleted_at + RESTORE_WINDOW)
  end
end
