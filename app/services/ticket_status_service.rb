class TicketStatusService
  Result = Struct.new(:success?, :ticket, :errors, keyword_init: true)

  def initialize(ticket, new_status, actor)
    @ticket     = ticket
    @new_status = new_status
    @actor      = actor
  end

  def call
    unless @ticket.can_transition_to?(@new_status)
      return Result.new(
        success?: false,
        ticket:   @ticket,
        errors:   [ "Transição de '#{@ticket.status}' para '#{@new_status}' não permitida" ]
      )
    end

    old_status = @ticket.status

    ActiveRecord::Base.transaction do
      @ticket.update!(status: @new_status)
      NotificationService.new(@ticket).notify_status_change(@actor, old_status, @new_status)

      # Fechar → consome todo o esforço estimado (effort_used = effort_estimated)
      if @new_status == "Fechado"
        est = @ticket.effort_estimated.to_f
        if est > 0 && @ticket.effort_used.to_f < est
          @ticket.update_columns(effort_used: est)
        end
      end

      # Terminal statuses → release future capacity and cancel running timers
      if terminal_status?(@new_status)
        release_capacity!
      end

      # Reopen → recalculate deadline and schedule for the assignee
      if @new_status == "Reaberto"
        reschedule_on_reopen!
      end
    end

    # Auditoria fora da transação — falha silenciosa não desfaz a mudança de status
    @ticket.organization.audit_logs.create(
      action:       "Status alterado",
      entity:       "Ticket",
      entity_id:    @ticket.id.to_s,
      changes_data: { de: old_status, para: @new_status, titulo: @ticket.title },
      user:         @actor
    )

    if @ticket.organization.emails_enabled?
      TicketMailer.status_changed(@ticket, old_status).deliver_later
      CsatSurveyJob.perform_later(@ticket.id) if @new_status == "Fechado"
    end

    Result.new(success?: true, ticket: @ticket, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, ticket: @ticket, errors: e.record.errors.full_messages)
  end

  private

  TERMINAL_STATUSES = %w[Resolvido Fechado].freeze
  REOPEN_STATUS     = "Reaberto"

  def terminal_status?(status)
    TERMINAL_STATUSES.include?(status)
  end

  # Cancels future scheduled capacity and any running timer for this ticket.
  def release_capacity!
    # Delete future scheduled days (today and forward) — past days are kept as historical record
    @ticket.scheduled_days.where("date >= ?", Date.current).destroy_all

    # Cancel any running timer session for this ticket
    if ActiveRecord::Base.connection.table_exists?(:ticket_timer_sessions)
      @ticket.timer_sessions.running.each(&:cancel!)
    end

    # Recalculate siblings' schedules so freed capacity is redistributed
    if @ticket.assignee_id.present?
      assignee = @ticket.organization.users.find_by(id: @ticket.assignee_id)
      ScheduleReallocationService.new(assignee, @ticket.organization).call if assignee
    end
  rescue StandardError => e
    # Never let reallocation errors roll back the status change
    Rails.logger.error("[TicketStatusService#release_capacity!] #{e.message}")
  end

  # Re-calculates deadline and schedule when a ticket is reopened.
  # Uses TicketDeadlineCalculator so the same algorithm as triage applies.
  def reschedule_on_reopen!
    return unless @ticket.assignee_id.present?

    calc = TicketDeadlineCalculator.new(@ticket).call
    if calc.deadline
      @ticket.update_columns(deadline: calc.deadline)
      ScheduleService.new(@ticket, calc.days).schedule
    end

    # Cascade: reallocation affects sibling tickets of the same assignee
    assignee = @ticket.organization.users.find_by(id: @ticket.assignee_id)
    ScheduleReallocationService.new(assignee, @ticket.organization).call if assignee
  rescue StandardError => e
    Rails.logger.error("[TicketStatusService#reschedule_on_reopen!] #{e.message}")
  end
end
