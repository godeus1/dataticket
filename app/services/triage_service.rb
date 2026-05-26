class TriageService
  Result = Struct.new(:success?, :ticket, :errors, keyword_init: true)

  def initialize(ticket, params, actor)
    @ticket = ticket
    @params = params
    @actor  = actor
  end

  def call
    ActiveRecord::Base.transaction do
      @ticket.assign_attributes(triage_params)
      @ticket.status = "Triado, aguardando atendimento"

      # Calcula prazo via agenda do responsável (ou fallback SLA se sem esforço/responsável)
      scheduler_result = run_agenda_scheduler
      @ticket.deadline = extract_deadline(scheduler_result)

      @ticket.save!
      @ticket.sync_co_assignees(@params[:co_assignee_ids]) if @params.key?(:co_assignee_ids)

      # Agenda os dias deste ticket no calendário do responsável
      apply_schedule(scheduler_result)

      # Recalcula prazos dos outros tickets do mesmo responsável (efeito cascata)
      recalculate_sibling_deadlines

      notify_assignee if @ticket.assignee_id.present?
    end

    audit_triage
    Result.new(success?: true, ticket: @ticket, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, ticket: @ticket, errors: e.record.errors.full_messages)
  rescue StandardError => e
    Result.new(success?: false, ticket: @ticket, errors: [ e.message ])
  end

  private

  # ── Agenda ───────────────────────────────────────────────────────────────

  # Executa a simulação de agenda para o responsável atual do ticket.
  # Retorna nil se não houver responsável ou esforço estimado.
  def run_agenda_scheduler
    assignee = find_assignee
    return nil unless assignee && @ticket.effort_estimated.to_f > 0

    AgendaSchedulerService.new(assignee, @ticket.organization).call(focus_ticket: @ticket)
  end

  # Extrai o prazo calculado para o ticket atual.
  # Fallback: SlaCalculator (baseado apenas no SLA da prioridade).
  def extract_deadline(result)
    if result
      date = result.deadline_for(AgendaSchedulerService::FOCUS_KEY)
      return date.to_time.end_of_day.in_time_zone if date
    end

    SlaCalculator.new(@ticket).calculate_deadline
  end

  # Grava os ScheduledDay do ticket com base na simulação.
  def apply_schedule(result)
    return unless @ticket.deadline.present? && @ticket.assignee_id.present?

    days = result&.days_for(AgendaSchedulerService::FOCUS_KEY) || {}
    ScheduleService.new(@ticket, days).schedule
  end

  # Recalcula e persiste os prazos dos outros tickets do mesmo responsável.
  # Necessário porque inserir um ticket crítico empurra os de menor prioridade.
  def recalculate_sibling_deadlines
    assignee = find_assignee
    return unless assignee

    # Nova simulação sem focus_ticket (usa os atributos já salvos de @ticket)
    result = AgendaSchedulerService.new(assignee, @ticket.organization).call
    result.deadlines.each do |ticket_id, date|
      next unless ticket_id.is_a?(Integer) && ticket_id != @ticket.id
      deadline_dt = date&.to_time&.end_of_day&.in_time_zone
      Ticket.where(id: ticket_id).update_all(deadline: deadline_dt)
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

  def find_assignee
    return nil unless @ticket.assignee_id.present?
    @assignee ||= @ticket.organization.users.find_by(id: @ticket.assignee_id)
  end

  def triage_params
    @params.permit(:priority_id, :category_id, :queue_id, :assignee_id, :deadline, :effort_estimated)
  end

  def notify_assignee
    assignee = find_assignee || User.find(@ticket.assignee_id)
    NotificationService.new(@ticket).notify_assignee(assignee)
  end

  def audit_triage
    @ticket.organization.audit_logs.create(
      action:       "Ticket triado",
      entity:       "Ticket",
      entity_id:    @ticket.id.to_s,
      changes_data: {
        titulo:      @ticket.title,
        responsavel: @ticket.assignee&.full_name,
        fila:        @ticket.queue&.name,
        prioridade:  @ticket.priority&.name,
        prazo:       @ticket.deadline&.strftime("%d/%m/%Y")
      }.compact,
      user: @actor
    )
  rescue StandardError
    # Auditoria nunca desfaz a triagem
  end
end
