require "prometheus/client"

# Application-level business metrics (singleton counters/gauges)
module DataticketMetrics
  REGISTRY = Prometheus::Client.registry

  TICKETS_CREATED = REGISTRY.counter(
    :tickets_created_total,
    docstring: "Total de tickets criados",
    labels:    %i[ticket_type organization_id]
  )

  TICKETS_RESOLVED = REGISTRY.counter(
    :tickets_resolved_total,
    docstring: "Total de tickets resolvidos",
    labels:    %i[organization_id]
  )

  TICKETS_ESCALATED = REGISTRY.counter(
    :tickets_escalated_total,
    docstring: "Total de tickets escalados por violação de SLA",
    labels:    %i[organization_id]
  )

  CSAT_SCORES = REGISTRY.histogram(
    :csat_score,
    docstring: "Distribuição de scores CSAT (1–5)",
    labels:    %i[organization_id],
    buckets:   [ 1, 2, 3, 4, 5 ]
  )

  def self.ticket_created(ticket)
    TICKETS_CREATED.increment(
      labels: { ticket_type: ticket.ticket_type,
                organization_id: ticket.organization_id.to_s }
    )
  rescue StandardError => e
    Rails.logger.error("[DataticketMetrics] #{e.message}")
  end

  def self.ticket_resolved(ticket)
    TICKETS_RESOLVED.increment(
      labels: { organization_id: ticket.organization_id.to_s }
    )
  rescue StandardError => e
    Rails.logger.error("[DataticketMetrics] #{e.message}")
  end

  def self.ticket_escalated(ticket)
    TICKETS_ESCALATED.increment(
      labels: { organization_id: ticket.organization_id.to_s }
    )
  rescue StandardError => e
    Rails.logger.error("[DataticketMetrics] #{e.message}")
  end

  def self.csat_submitted(ticket)
    return unless ticket.csat_score.present?

    CSAT_SCORES.observe(
      ticket.csat_score,
      labels: { organization_id: ticket.organization_id.to_s }
    )
  rescue StandardError => e
    Rails.logger.error("[DataticketMetrics] #{e.message}")
  end
end
