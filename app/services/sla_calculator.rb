class SlaCalculator
  # Fallback SLA hours per priority name when no SlaPolicy or Priority#sla_hours found
  DEFAULT_SLA = {
    "Crítica" => 4,
    "Alta"    => 8,
    "Média"   => 24,
    "Baixa"   => 72
  }.freeze

  def initialize(ticket)
    @ticket       = ticket
    @organization = ticket.organization
  end

  def calculate_deadline
    hours = sla_hours
    return nil unless hours

    start_time = @ticket.created_at || Time.current
    add_business_hours(start_time, hours)
  end

  private

  # Resolution hierarchy (most specific → least specific):
  #   1. SlaPolicy matching priority + category
  #   2. SlaPolicy matching priority only
  #   3. SlaPolicy matching category only
  #   4. Priority#sla_hours
  #   5. DEFAULT_SLA by priority name
  def sla_hours
    policy = SlaPolicy.find_for(
      organization: @organization,
      priority:     @ticket.priority,
      category:     @ticket.category
    )
    return policy.resolve_hours if policy

    return @ticket.priority.sla_hours if @ticket.priority&.sla_hours&.positive?

    DEFAULT_SLA[@ticket.priority&.name]
  end

  def add_business_hours(start_time, hours)
    holidays  = @organization.holidays.pluck(:date).map(&:to_date)
    current   = start_time
    remaining = hours.to_f

    while remaining > 0
      current += 1.hour
      next if holidays.include?(current.to_date)
      next if current.saturday? || current.sunday?
      next unless business_hour?(current)

      remaining -= 1
    end

    current
  end

  def business_hour?(time)
    time.hour >= 8 && time.hour < 18
  end
end
