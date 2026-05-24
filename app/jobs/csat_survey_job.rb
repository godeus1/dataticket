class CsatSurveyJob < ApplicationJob
  queue_as :default

  def perform(ticket_id)
    ticket = Ticket.find_by(id: ticket_id)
    return unless ticket
    return unless ticket.status == "Fechado"
    return unless ticket.organization.emails_enabled?
    return if ticket.csat_sent_at.present?  # ja enviado

    CsatMailer.survey(ticket).deliver_now
    ticket.update_column(:csat_sent_at, Time.current)
  end
end
