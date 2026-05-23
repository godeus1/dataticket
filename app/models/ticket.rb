class Ticket < ApplicationRecord
  self.primary_key = "id"

  belongs_to :organization
  belongs_to :requester, class_name: "User", foreign_key: :requester_id
  belongs_to :assignee,  class_name: "User", foreign_key: :assignee_id, optional: true
  belongs_to :category,  optional: true
  belongs_to :priority,  optional: true
  belongs_to :queue,     class_name: "TicketQueue", optional: true

  has_many :comments,      class_name: "TicketComment",    foreign_key: :ticket_id, dependent: :destroy
  has_many :histories,     class_name: "TicketHistory",    foreign_key: :ticket_id, dependent: :destroy
  has_many :ticket_attachments, foreign_key: :ticket_id, dependent: :destroy
  alias_method :attachments, :ticket_attachments
  has_many :notifications,                                 foreign_key: :ticket_id, dependent: :nullify
  has_many :scheduled_days,                                foreign_key: :ticket_id, dependent: :destroy
  has_many :ticket_tags,   foreign_key: :ticket_id, dependent: :destroy
  has_many :tags,          through: :ticket_tags
  has_many :field_values,  class_name: "TicketFieldValue", foreign_key: :ticket_id, dependent: :destroy

  TICKET_TYPES = %w[incidente problema mudança requisição].freeze

  STATUSES = [
    "Não iniciado",
    "Triado, aguardando atendimento",
    "Em andamento",
    "Aguardando terceiros",
    "Aguardando solicitante",
    "Resolvido",
    "Fechado",
    "Reaberto"
  ].freeze

  ALLOWED_TRANSITIONS = {
    "Não iniciado"                   => [ "Triado, aguardando atendimento", "Em andamento", "Fechado" ],
    "Triado, aguardando atendimento" => [ "Em andamento", "Aguardando terceiros", "Aguardando solicitante", "Fechado" ],
    "Em andamento"                   => [ "Aguardando terceiros", "Aguardando solicitante", "Resolvido", "Fechado" ],
    "Aguardando terceiros"           => [ "Em andamento", "Resolvido", "Fechado" ],
    "Aguardando solicitante"         => [ "Em andamento", "Resolvido", "Fechado" ],
    "Resolvido"                      => [ "Reaberto", "Fechado" ],
    "Fechado"                        => [ "Reaberto" ],
    "Reaberto"                       => [ "Em andamento", "Triado, aguardando atendimento" ]
  }.freeze

  validates :title,       presence: true, length: { maximum: 255 }
  validates :status,      inclusion: { in: STATUSES }
  validates :ticket_type, inclusion: { in: TICKET_TYPES }
  validates :csat_score,  inclusion: { in: 1..5 }, allow_nil: true

  # Campos auditados além de status
  TRACKED_ASSOCIATIONS = {
    "assignee_id"  => ->(org, id) { id ? org.users.find_by(id: id)&.then { |u| "#{u.first_name} #{u.last_name}" } : nil },
    "priority_id"  => ->(org, id) { id ? org.priorities.find_by(id: id)&.name : nil },
    "category_id"  => ->(org, id) { id ? org.categories.find_by(id: id)&.name : nil },
    "queue_id"     => ->(org, id) { id ? org.queues.find_by(id: id)&.name : nil }
  }.freeze

  before_create        :generate_ticket_id
  before_create        :generate_csat_token
  before_save          :stamp_resolved_at,        if: :will_save_change_to_status?
  after_update         :record_status_history,    if: :saved_change_to_status?
  after_update         :record_field_histories
  after_update_commit  :schedule_csat_survey,     if: -> { saved_change_to_status? && status == "Fechado" }

  after_create_commit  :broadcast_ticket_created
  after_update_commit  :broadcast_ticket_updated

  after_create_commit  :run_auto_triage
  after_create_commit  :fire_webhook_created
  after_update_commit  :fire_webhook_updated

  # Event sourcing
  after_create_commit  :publish_created_event
  after_update_commit  :publish_updated_event

  # Prometheus metrics
  after_create_commit  -> { DataticketMetrics.ticket_created(self) }
  after_update_commit  -> {
    DataticketMetrics.ticket_resolved(self) if saved_change_to_status? && status == "Resolvido"
    DataticketMetrics.ticket_escalated(self) if saved_change_to_escalated? && escalated?
  }

  scope :open,      -> { where.not(status: %w[Resolvido Fechado]) }
  scope :overdue,   -> { open.where("deadline < ?", Time.current) }
  scope :by_period, ->(days) { where("created_at >= ?", days.days.ago) }

  def sla_expired?
    deadline.present? && deadline < Time.current && !%w[Resolvido Fechado].include?(status)
  end

  def can_transition_to?(new_status)
    ALLOWED_TRANSITIONS[status]&.include?(new_status)
  end

  private

  # ── CSAT: gera token único para URL de avaliação ──────────────────────────────
  def generate_csat_token
    self.csat_token = SecureRandom.urlsafe_base64(24)
  end

  # ── CSAT: agenda envio do survey após fechamento ───────────────────────────────
  def schedule_csat_survey
    CsatSurveyJob.set(wait: 1.hour).perform_later(id)
  end

  # ── ID geração com lock para evitar race condition ───────────────────────────
  # organization.with_lock faz SELECT ... FOR UPDATE na linha da organização,
  # serializando a geração de IDs por organização.
  def generate_ticket_id
    organization.with_lock do
      last_num = organization.tickets
                             .where("id ~ ?", "^TK-\\d+$")
                             .maximum("CAST(SUBSTRING(id, 4) AS INTEGER)") || 0
      self.id = "TK-#{format('%04d', last_num + 1)}"
    end
  end

  # ── Registra histórico de campos de associação (assignee, priority, category, queue) ──
  def record_field_histories
    actor = Current.user || assignee || requester
    TRACKED_ASSOCIATIONS.each do |field, resolver|
      next unless saved_changes.key?(field)

      old_id, new_id = saved_changes[field]
      histories.create!(
        user:       actor,
        field:      field.sub("_id", ""),
        from_value: resolver.call(organization, old_id),
        to_value:   resolver.call(organization, new_id)
      )
    end
  end

  # ── Registra histórico de status com o actor real (Current.user) ─────────────
  def record_status_history
    actor = Current.user || assignee || requester
    histories.create!(
      user:       actor,
      field:      "status",
      from_value: saved_change_to_status.first,
      to_value:   saved_change_to_status.last
    )
  end

  # ── Marca resolved_at no mesmo UPDATE (evita segundo UPDATE via update_column) ─
  def stamp_resolved_at
    if will_save_change_to_status? &&
       %w[Resolvido Fechado].include?(status_in_database == status ? status : changes["status"]&.last) &&
       resolved_at.nil?
      self.resolved_at = Time.current
    end

    # Reabertura: limpa resolved_at
    if will_save_change_to_status? && status == "Reaberto"
      self.resolved_at = nil
    end
  end

  def broadcast_ticket_created
    TicketsChannel.broadcast_to(
      organization,
      { event: "ticket_created", ticket: TicketBlueprint.render_as_hash(self, view: :summary) }
    )
  end

  def broadcast_ticket_updated
    TicketsChannel.broadcast_to(
      organization,
      { event: "ticket_updated", ticket: TicketBlueprint.render_as_hash(self, view: :summary) }
    )
  end

  def publish_created_event
    EventStore.publish(
      event_type:   "ticket.created",
      aggregate:    self,
      payload:      { title: title, ticket_type: ticket_type, status: status },
      actor:        Current.user || requester
    )
  end

  def publish_updated_event
    changes_payload = saved_changes.except("updated_at")
    return if changes_payload.empty?

    type = if saved_change_to_status?
             status == "Fechado" ? "ticket.closed" : "ticket.status_changed"
           elsif saved_change_to_assignee_id?
             "ticket.assigned"
           elsif saved_change_to_escalated? && escalated?
             "ticket.escalated"
           else
             "ticket.updated"
           end

    EventStore.publish(
      event_type: type,
      aggregate:  self,
      payload:    changes_payload,
      actor:      Current.user
    )
  end

  def run_auto_triage
    AutoTriageService.new(self).apply
  rescue StandardError => e
    Rails.logger.error("[AutoTriageService] ticket #{id}: #{e.message}")
  end

  def fire_webhook_created
    WebhookDeliveryJob.perform_later(
      organization_id,
      "ticket.created",
      TicketBlueprint.render_as_hash(self, view: :summary)
    )
  end

  def fire_webhook_updated
    event = if saved_change_to_status?
              status == "Fechado" ? "ticket.closed" : "ticket.status_changed"
            elsif saved_change_to_assignee_id?
              "ticket.assigned"
            elsif saved_change_to_escalated? && escalated?
              "ticket.escalated"
            else
              "ticket.updated"
            end

    WebhookDeliveryJob.perform_later(
      organization_id,
      event,
      TicketBlueprint.render_as_hash(self, view: :summary)
    )
  end
end
