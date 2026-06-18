# frozen_string_literal: true
# Remove permanentemente tickets E anexos na lixeira há mais de 30 dias.
class TrashCleanupJob < ApplicationJob
  queue_as :default

  RETENTION_DAYS = 30

  def perform
    cutoff = RETENTION_DAYS.days.ago

    tickets      = Ticket.trashed.where("deleted_at < ?", cutoff)
    ticket_count = tickets.count
    tickets.destroy_all

    # Anexos na lixeira > 30 dias: remove o arquivo do storage e o registro.
    attachments = TicketAttachment.trashed.where("deleted_at < ?", cutoff)
    att_count   = attachments.count
    attachments.find_each do |att|
      S3Uploader.delete(att.storage_key)
      att.destroy!
    end

    Rails.logger.info("[TrashCleanupJob] #{ticket_count} ticket(s) e #{att_count} anexo(s) excluídos permanentemente (> #{RETENTION_DAYS} dias na lixeira)")
  end
end
