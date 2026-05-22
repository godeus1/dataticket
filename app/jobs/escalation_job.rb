class EscalationJob < ApplicationJob
  queue_as :critical

  def perform
    Ticket.open.overdue.where(escalated: false).find_each do |ticket|
      next unless ticket.deadline.present?

      sla_duration = ticket.deadline - ticket.created_at
      elapsed      = Time.current - ticket.created_at

      next unless sla_duration > 0 && elapsed > sla_duration * 1.2

      EscalationService.new(ticket).escalate
    end
  end
end
