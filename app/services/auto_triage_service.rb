class AutoTriageService
  def initialize(ticket)
    @ticket       = ticket
    @organization = ticket.organization
  end

  # Applies the first matching triage rule (by position ASC).
  # Returns the matched rule or nil if none matched.
  def apply
    rules = @organization.triage_rules.active.ordered
                          .includes(:category, :priority, :queue)

    rules.each do |rule|
      next unless matches?(rule)

      apply_rule(rule)
      return rule
    end

    nil
  end

  private

  def matches?(rule)
    text = "#{@ticket.title} #{@ticket.description}".downcase
    text.include?(rule.keyword.downcase)
  end

  def apply_rule(rule)
    updates = {}
    updates[:category_id] = rule.category_id if rule.category_id.present?
    updates[:priority_id] = rule.priority_id if rule.priority_id.present?
    updates[:queue_id]    = rule.queue_id    if rule.queue_id.present?
    return if updates.empty?

    @ticket.assign_attributes(updates)

    # Recalculate deadline if priority was set by rule
    if updates[:priority_id].present? && @ticket.deadline.nil?
      @ticket.deadline = SlaCalculator.new(@ticket).calculate_deadline
    end

    @ticket.save!
  end
end
