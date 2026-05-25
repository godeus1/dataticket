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
end
