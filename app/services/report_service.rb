class ReportService
  def initialize(organization, params = {})
    @organization = organization
    @params       = params
    @period       = params[:period]&.to_i || 30
  end

  def call
    {
      summary:             summary,
      by_status:           by_status,
      by_priority:         by_priority,
      by_category:         by_category,
      by_ticket_type:      by_ticket_type,
      by_assignee:         by_assignee,
      sla_compliance:      sla_compliance,
      avg_resolution_time: avg_resolution_time,
      volume_by_day:       volume_by_day,
      csat:                csat_summary,
      escalated_count:     escalated_count
    }
  end

  private

  def base_scope
    @organization.tickets.by_period(@period)
  end

  def summary
    {
      total:    base_scope.count,
      open:     base_scope.open.count,
      overdue:  base_scope.overdue.count,
      resolved: base_scope.where(status: %w[Resolvido Fechado]).count
    }
  end

  def by_status
    base_scope.group(:status).count
  end

  def by_priority
    base_scope.joins(:priority).group("priorities.name").count
  end

  def by_category
    base_scope.joins(:category).group("categories.name").count
  end

  def by_assignee
    base_scope
      .joins(:assignee)
      .group("users.first_name", "users.last_name", "users.id")
      .count
      .map { |(first, last, id), count| { id: id, name: "#{first} #{last}", count: count } }
  end

  def sla_compliance
    with_deadline = base_scope.where.not(deadline: nil)
    total         = with_deadline.count
    return { rate: nil, total: 0 } if total.zero?

    on_time = with_deadline
                .where("resolved_at IS NULL OR resolved_at <= deadline")
                .count

    { rate: (on_time.to_f / total * 100).round(1), total: total }
  end

  def avg_resolution_time
    resolved = base_scope.where.not(resolved_at: nil)
    return nil if resolved.empty?

    avg_seconds = resolved
                    .average("EXTRACT(EPOCH FROM (resolved_at - created_at))")
                    &.to_f

    return nil unless avg_seconds

    (avg_seconds / 3600).round(1)
  end

  def by_ticket_type
    base_scope.group(:ticket_type).count
  end

  def volume_by_day
    base_scope
      .group("DATE(created_at AT TIME ZONE 'UTC' AT TIME ZONE '#{@organization.timezone}')")
      .order("1 ASC")
      .count
      .map { |date, count| { date: date.to_s, count: count } }
  end

  def csat_summary
    rated = base_scope.where.not(csat_score: nil)
    total = rated.count
    return { avg: nil, total: 0, distribution: {} } if total.zero?

    avg          = rated.average(:csat_score)&.round(2)
    distribution = rated.group(:csat_score).count

    { avg: avg, total: total, distribution: distribution }
  end

  def escalated_count
    base_scope.where(escalated: true).count
  end
end
