class TicketRescheduleJob < ApplicationJob
  queue_as :default

  # Executa o reagendamento de agenda após update de ticket de forma assíncrona.
  # O destroy_all dos scheduled_days do antigo responsável ocorre no controller
  # (síncrono) para evitar double-booking imediato. Este job cuida apenas do
  # recálculo pesado via ScheduleReallocationService.
  #
  # old_assignee_id: ID do responsável anterior (nil se não mudou)
  def perform(ticket_id, old_assignee_id)
    ticket = Ticket.find_by(id: ticket_id)
    return unless ticket

    org             = ticket.organization
    new_assignee_id = ticket.assignee_id

    assignee_changed = old_assignee_id.present? &&
                       old_assignee_id.to_s != new_assignee_id.to_s

    if assignee_changed
      old_assignee = org.users.find_by(id: old_assignee_id)
      ScheduleReallocationService.new(old_assignee, org).call if old_assignee
    end

    if new_assignee_id.present?
      new_assignee = org.users.find_by(id: new_assignee_id)
      ScheduleReallocationService.new(new_assignee, org).call if new_assignee
    end
  rescue StandardError => e
    Rails.logger.error("[TicketRescheduleJob] ticket #{ticket_id}: #{e.message}")
    raise  # re-raise para que o queue adapter registre a falha e retentar
  end
end
