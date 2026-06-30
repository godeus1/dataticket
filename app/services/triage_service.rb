class TriageService
  Result = Struct.new(:success?, :ticket, :errors, keyword_init: true)

  def initialize(ticket, params, actor)
    @ticket = ticket
    @params = params
    @actor  = actor
  end

  def call
    ActiveRecord::Base.transaction do
      effort_before = @ticket.effort_estimated.to_f
      attrs = triage_params.to_h.symbolize_keys

      # Se o ticket já tem esforço estimado e um novo valor foi informado, soma
      if attrs.key?(:effort_estimated) && @ticket.effort_estimated.to_f > 0
        extra = attrs[:effort_estimated].to_f
        if extra > 0
          old_estimated  = @ticket.effort_estimated.to_f
          attrs[:effort_estimated] = (old_estimated + extra).round(2)
          @extra_effort  = extra
          @old_estimated = old_estimated
        else
          attrs.delete(:effort_estimated)
        end
      end

      @ticket.assign_attributes(attrs)
      @ticket.status = "Triado, aguardando atendimento"

      # Calcula prazo e alocação diária via TicketDeadlineCalculator
      calc_result      = run_deadline_calculator
      @ticket.deadline = calc_result.deadline

      @ticket.save!
      @ticket.sync_co_assignees(@params[:co_assignee_ids]) if @params.key?(:co_assignee_ids)

      # Registra a adição de esforço da triagem na lista lateral do ticket
      # (o esforço já foi atualizado acima — aqui só cria o registro).
      delta = (@ticket.effort_estimated.to_f - effort_before).round(2)
      if delta > 0
        @ticket.effort_additions.create!(user: @actor, hours: delta, reason: "Triagem", source: "triage") rescue nil
      end

      # Registra histórico de acréscimo de esforço quando re-triagem soma horas
      if @extra_effort&.> 0
        @ticket.histories.create!(
          user:       @actor,
          field:      "esforço estimado (re-triagem)",
          from_value: "#{@old_estimated} h",
          to_value:   "#{@ticket.effort_estimated} h (+#{@extra_effort} h)"
        ) rescue nil
      end

      # Agenda os dias deste ticket no calendário do responsável
      apply_schedule(calc_result)

      notify_assignee if @ticket.assignee_id.present?
    end

    # Recalcula prazos dos tickets irmãos fora da transação e de forma assíncrona.
    # ScheduleReallocationService é O(N²) — não deve bloquear a resposta HTTP de triagem.
    # old_assignee_id = nil → TicketRescheduleJob realloca apenas o responsável atual.
    TicketRescheduleJob.perform_later(@ticket.id, nil) if @ticket.assignee_id.present?

    audit_triage
    Result.new(success?: true, ticket: @ticket, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, ticket: @ticket, errors: e.record.errors.full_messages)
  rescue StandardError => e
    Result.new(success?: false, ticket: @ticket, errors: [ e.message ])
  end

  private

  # ── Agenda ───────────────────────────────────────────────────────────────

  # Calcula prazo e obtém alocação diária via TicketDeadlineCalculator.
  def run_deadline_calculator
    TicketDeadlineCalculator.new(@ticket).call
  end

  # Grava os ScheduledDay do ticket com base nos dias calculados.
  def apply_schedule(calc_result)
    return unless @ticket.deadline.present? && @ticket.assignee_id.present?
    ScheduleService.new(@ticket, calc_result.days).schedule
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
    @ticket.organization.record_audit(
      event:     "ticket_changed",
      action:    "Ticket triado",
      entity:    "Ticket",
      entity_id: @ticket.id,
      changes:   {
        titulo:      @ticket.title,
        responsavel: @ticket.assignee&.full_name,
        fila:        @ticket.queue&.name,
        prioridade:  @ticket.priority&.name,
        prazo:       @ticket.deadline&.strftime("%d/%m/%Y")
      },
      user: @actor
    )
  end
end
