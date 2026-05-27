class EscalationJob < ApplicationJob
  queue_as :critical

  # Varredura de tickets que precisam ser escalados.
  # Despacha um EscalationTicketJob por ticket — falhas individuais ficam isoladas
  # e o processamento dos demais não é interrompido.
  def perform
    Ticket.open.overdue.where(escalated: false).pluck(:id).each do |ticket_id|
      EscalationTicketJob.perform_later(ticket_id)
    end
  end
end
