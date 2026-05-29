# TicketDeadlineCalculator
#
# Ponto único de cálculo de prazo para um ticket.
# Encapsula a lógica que estava duplicada em TriageService, TicketsController#assign
# e ScheduleReallocationService.
#
# Algoritmo:
#   1. Se o ticket tem responsável E esforço estimado → usa AgendaSchedulerService
#      (respeita carga existente do responsável, prioridade e feriados)
#   2. Caso contrário → usa SlaCalculator (data de abertura + SLA da prioridade)
#
# Retorno:
#   Result struct com:
#     deadline          – Time (fim do último dia de trabalho) ou nil
#     scheduler_result  – AgendaSchedulerService::Result ou nil
#     days              – Hash { Date => Float } de alocação diária (vazio se fallback SLA)
#
class TicketDeadlineCalculator
  Result = Struct.new(:deadline, :scheduler_result, :days, keyword_init: true)

  def initialize(ticket)
    @ticket = ticket
  end

  def call
    assignee = find_assignee
    if assignee && @ticket.effort_estimated.to_f > 0
      agenda_result(assignee)
    else
      sla_result
    end
  end

  private

  def find_assignee
    return nil unless @ticket.assignee_id.present?
    @ticket.organization.users.find_by(id: @ticket.assignee_id)
  end

  def agenda_result(assignee)
    sched = AgendaSchedulerService.new(assignee, @ticket.organization).call(focus_ticket: @ticket)
    date  = sched.deadline_for(AgendaSchedulerService::FOCUS_KEY)
    days  = sched.days_for(AgendaSchedulerService::FOCUS_KEY)

    if date
      Result.new(
        deadline:         date.to_time.end_of_day.in_time_zone,
        scheduler_result: sched,
        days:             days
      )
    else
      # Scheduler ran but couldn't fit the ticket (e.g., 730-day cap) — fallback to SLA
      sla = SlaCalculator.new(@ticket).calculate_deadline
      Result.new(deadline: sla, scheduler_result: sched, days: {})
    end
  end

  def sla_result
    Result.new(
      deadline:         SlaCalculator.new(@ticket).calculate_deadline,
      scheduler_result: nil,
      days:             {}
    )
  end
end
