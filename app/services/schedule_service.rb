class ScheduleService
  def initialize(ticket)
    @ticket = ticket
  end

  def schedule
    return unless @ticket.deadline.present? && @ticket.assignee.present?

    assignee     = @ticket.assignee
    hours_per_day = [assignee.max_hours_per_ticket, assignee.available_hours].min

    @ticket.scheduled_days.where(user: assignee).destroy_all

    holidays = @ticket.organization.holidays.pluck(:date).map(&:to_date)
    current  = @ticket.created_at&.to_date || Date.current
    end_date = @ticket.deadline.to_date

    while current <= end_date
      unless current.saturday? || current.sunday? || holidays.include?(current)
        @ticket.scheduled_days.create!(
          user:  assignee,
          date:  current,
          hours: hours_per_day
        )
      end
      current += 1.day
    end
  end
end
