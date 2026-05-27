class CsatSurveyJob < ApplicationJob
  queue_as :default

  def perform(ticket_id)
    ticket = Ticket.find_by(id: ticket_id)
    return unless ticket
    return unless ticket.status == "Fechado"
    return unless ticket.organization.emails_enabled?

    # Atomic check-and-set: garante idempotência em caso de retry do job.
    # Se o UPDATE retornar 0 linhas, outro worker já marcou → aborta silenciosamente.
    rows_updated = Ticket.where(id: ticket_id, csat_sent_at: nil)
                         .update_all(csat_sent_at: Time.current)
    return if rows_updated == 0

    # Só envia o e-mail após a marcação atômica
    ticket.reload
    CsatMailer.survey(ticket).deliver_later
  end
end
