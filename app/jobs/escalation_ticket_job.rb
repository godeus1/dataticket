class EscalationTicketJob < ApplicationJob
  queue_as :critical

  # Processa a escalação de um único ticket de forma isolada.
  # Separado do EscalationJob (que faz a varredura) para que falhas individuais
  # não interrompam o processamento dos demais tickets.
  def perform(ticket_id)
    ticket = Ticket.find_by(id: ticket_id)
    return unless ticket
    return if ticket.escalated?
    return unless ticket.deadline.present?

    sla_duration = ticket.deadline - ticket.created_at
    elapsed      = Time.current - ticket.created_at

    return unless sla_duration > 0 && elapsed > sla_duration * 1.2

    EscalationService.new(ticket).escalate
  rescue StandardError => e
    Rails.logger.error("[EscalationTicketJob] ticket #{ticket_id}: #{e.message}")
    raise
  end
end
