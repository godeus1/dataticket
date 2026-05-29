# UserCapacityService
#
# Calcula a carga de trabalho de um usuário em um intervalo de datas,
# somando as horas agendadas nos ScheduledDays.
#
# Usado para:
#   - Picker de responsável no frontend (badge de carga)
#   - Endpoint GET /api/v1/users/capacity
#
class UserCapacityService
  # Retorna um hash com métricas de capacidade para um array de usuários.
  #
  # Params:
  #   users        - ActiveRecord::Relation ou Array de User
  #   organization - Organization (para acessar feriados e tickets)
  #   from         - Date início do período (default: hoje)
  #   to           - Date fim do período (default: 7 dias)
  #
  # Retorna:
  #   Array de hashes, um por usuário:
  #   {
  #     user_id:          <String>,
  #     available_hours:  <Float>,   # horas disponíveis/dia * dias úteis no período
  #     scheduled_hours:  <Float>,   # soma das horas já agendadas no período
  #     free_hours:       <Float>,   # available_hours - scheduled_hours (pode ser negativo)
  #     load_pct:         <Integer>, # percentual de ocupação 0-100+ (pode passar de 100)
  #     working_days:     <Integer>, # qtd de dias úteis no período
  #   }
  #
  def self.call(users:, organization:, from: Date.current, to: Date.current + 6)
    new(users: users, organization: organization, from: from, to: to).call
  end

  def initialize(users:, organization:, from:, to:)
    @users        = Array(users)
    @organization = organization
    @from         = from
    @to           = to
  end

  def call
    holidays       = load_holidays
    working_days   = count_working_days(@from, @to, holidays)
    scheduled      = load_scheduled_hours

    @users.map do |user|
      avail    = user.available_hours.to_f * working_days
      sched    = (scheduled[user.id] || 0.0).round(2)
      free     = (avail - sched).round(2)
      load_pct = avail > 0 ? ((sched / avail) * 100).round : 0

      {
        user_id:         user.id,
        available_hours: avail.round(2),
        scheduled_hours: sched,
        free_hours:      free,
        load_pct:        load_pct,
        working_days:    working_days,
      }
    end
  end

  private

  def load_holidays
    @organization.holidays.map { |h| { recurring: h.recurring, date: h.date.to_date } }
  end

  def count_working_days(from, to, holidays)
    count = 0
    date  = from
    while date <= to
      unless date.saturday? || date.sunday? || holiday_on?(date, holidays)
        count += 1
      end
      date += 1
    end
    count
  end

  def holiday_on?(date, holidays)
    holidays.any? do |h|
      h[:recurring] ? (h[:date].month == date.month && h[:date].day == date.day) : h[:date] == date
    end
  end

  # Sum scheduled hours per user for the given date range.
  # Only counts tickets with actual remaining effort (effort_estimated > effort_used).
  def load_scheduled_hours
    user_ids = @users.map(&:id)
    rows = ScheduledDay
      .joins(:ticket)
      .where(user_id: user_ids)
      .where(date: @from..@to)
      .where(tickets: { deleted_at: nil })
      .where.not(tickets: { status: %w[Resolvido Fechado] })
      .where("tickets.effort_estimated > tickets.effort_used")
      .where("tickets.effort_estimated > 0")
      .group(:user_id)
      .sum(:hours)

    # rows keys may be integers depending on DB — normalise to match user.id type
    rows.transform_keys { |k| k.to_s }
        .tap { |h| user_ids.each { |uid| h[uid.to_s] ||= 0.0 } }
  end
end
