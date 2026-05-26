class ScheduleService
  # daily_hours: Hash { Date => Float } produzido pelo AgendaSchedulerService.
  # Se nil, usa o fallback linear (comportamento legado).
  def initialize(ticket, daily_hours = nil)
    @ticket      = ticket
    @daily_hours = daily_hours
  end

  def schedule
    return unless @ticket.assignee.present?

    assignee = @ticket.assignee
    @ticket.scheduled_days.where(user: assignee).destroy_all

    if @daily_hours.present?
      @daily_hours.each do |date, hours|
        @ticket.scheduled_days.create!(user: assignee, date: date, hours: hours.round(2))
      end
    else
      schedule_legacy(assignee)
    end
  end

  private

  # Fallback: distribui horas linearmente entre abertura e prazo
  # (usado quando AgendaSchedulerService não retorna dados — ex: esforço = 0)
  def schedule_legacy(assignee)
    return unless @ticket.deadline.present?

    hours_per_day = [ assignee.max_hours_per_ticket, assignee.available_hours ].min
    holidays      = @ticket.organization.holidays.pluck(:date).map(&:to_date)
    current       = @ticket.created_at&.to_date || Date.current
    end_date      = @ticket.deadline.to_date

    while current <= end_date
      unless current.saturday? || current.sunday? || holidays.include?(current)
        @ticket.scheduled_days.create!(user: assignee, date: current, hours: hours_per_day)
      end
      current += 1.day
    end
  end
end
