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
      @ticket.deadline = SlaCalculator.new(@ticket).calculate_deadline
      schedule_if_needed
      @ticket.save!
      @ticket.sync_co_assignees(@params[:co_assignee_ids]) if @params.key?(:co_assignee_ids)
      notify_assignee if @ticket.assignee_id.present?
    end

    Result.new(success?: true, ticket: @ticket, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, ticket: @ticket, errors: e.record.errors.full_messages)
  rescue StandardError => e
    Result.new(success?: false, ticket: @ticket, errors: [ e.message ])
  end

  private

  def triage_params
    @params.permit(:priority_id, :category_id, :queue_id, :assignee_id, :deadline)
  end

  def schedule_if_needed
    return unless @ticket.deadline.present?

    ScheduleService.new(@ticket).schedule
  end

  def notify_assignee
    assignee = User.find(@ticket.assignee_id)
    NotificationService.new(@ticket).notify_assignee(assignee)
  end
end
