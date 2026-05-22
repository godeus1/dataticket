class EventStore
  # Publishes a domain event as an immutable record.
  #
  # @param event_type   [String]  e.g. "ticket.created"
  # @param aggregate    [AR model] the primary entity (Ticket, User, …)
  # @param payload      [Hash]    additional data snapshot
  # @param actor        [User, nil] who triggered the event
  # @param organization [Organization] tenant scope
  def self.publish(event_type:, aggregate:, payload: {}, actor: nil, organization: nil)
    org = organization ||
          (aggregate.respond_to?(:organization) ? aggregate.organization : nil)

    return unless org  # silently skip if no org context (e.g. during seeds)

    # Compute next version for this aggregate stream
    last_version = Event.where(
      aggregate_type: aggregate.class.name,
      aggregate_id:   aggregate.id.to_s
    ).maximum(:version) || 0

    Event.create!(
      aggregate_type: aggregate.class.name,
      aggregate_id:   aggregate.id.to_s,
      event_type:     event_type,
      payload:        payload.to_h,
      actor:          actor,
      organization:   org,
      occurred_at:    Time.current,
      version:        last_version + 1
    )
  rescue StandardError => e
    # Event sourcing must never crash the main flow
    Rails.logger.error("[EventStore] publish failed: #{e.message}")
    nil
  end
end
