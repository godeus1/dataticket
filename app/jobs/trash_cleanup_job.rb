# frozen_string_literal: true
# Remove permanentemente tickets na lixeira há mais de 30 dias.
class TrashCleanupJob < ApplicationJob
  queue_as :default

  RETENTION_DAYS = 30

  def perform
    cutoff  = RETENTION_DAYS.days.ago
    tickets = Ticket.trashed.where("deleted_at < ?", cutoff)
    count   = tickets.count
    tickets.destroy_all
    Rails.logger.info("[TrashCleanupJob] #{count} ticket(s) excluídos permanentemente (> #{RETENTION_DAYS} dias na lixeira)")
  end
end
