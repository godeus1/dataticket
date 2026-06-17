class Ticket < ApplicationRecord
  self.primary_key = "id"

  belongs_to :organization
  belongs_to :requester, class_name: "User", foreign_key: :requester_id
  belongs_to :assignee,  class_name: "User", foreign_key: :assignee_id, optional: true

  has_many :ticket_assignees, dependent: :destroy
  has_many :co_assignees, through: :ticket_assignees, class_name: "User", source: :user
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
  has_many :timer_sessions, class_name: "TicketTimerSession", foreign_key: :ticket_id, dependent: :destroy

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
    "Em andamento"                   => [ "Triado, aguardando atendimento", "Aguardando terceiros", "Aguardando solicitante", "Resolvido", "Fechado" ],
    "Aguardando terceiros"           => [ "Em andamento", "Resolvido", "Fechado" ],
    "Aguardando solicitante"         => [ "Em andamento", "Resolvido", "Fechado" ],
    "Resolvido"                      => [ "Reaberto", "Fechado" ],
    "Fechado"                        => [ "Reaberto" ],
    "Reaberto"                       => [ "Em andamento", "Triado, aguardando atendimento", "Fechado" ]
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

  scope :active,    -> { where(deleted_at: nil) }
  scope :trashed,   -> { where.not(deleted_at: nil) }
  scope :open,      -> { active.where.not(status: %w[Resolvido Fechado]) }
  scope :overdue,   -> { open.where("deadline < ?", Time.current) }
  scope :by_period, ->(days) { active.where("created_at >= ?", days.days.ago) }

  def soft_delete!(actor)
    update!(deleted_at: Time.current, deleted_by_id: actor.id)
    histories.create!(
      user:       actor,
      field:      "deleted",
      from_value: nil,
      to_value:   "Movido para lixeira por #{actor.full_name}"
    )
  end

  def restore!(actor)
    update!(deleted_at: nil, deleted_by_id: nil)
    histories.create!(
      user:       actor,
      field:      "deleted",
      from_value: "Lixeira",
      to_value:   "Restaurado por #{actor.full_name}"
    )
  end

  # Sincroniza co_assignees a partir de um array de IDs.
  # insert_all em lote substitui o loop de create! (N inserts → 1 insert).
  # TicketAssignee não possui callbacks, portanto insert_all é seguro.
  def sync_co_assignees(user_ids)
    ids = Array(user_ids).map(&:to_i).uniq.reject(&:zero?)
    current   = ticket_assignees.pluck(:user_id)
    to_add    = ids - current
    to_remove = current - ids

    ticket_assignees.where(user_id: to_remove).destroy_all

    if to_add.any?
      now = Time.current
      TicketAssignee.insert_all(
        to_add.map { |uid| { ticket_id: id, user_id: uid, created_at: now, updated_at: now } }
      )
    end
  end

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

  # ── ID geração via contador atômico por organização ──────────────────────────
  # ON CONFLICT DO UPDATE atomicamente incrementa e retorna o novo valor.
  # Substitui o with_lock + MAX(CAST(REGEX)) anterior:
  # - Sem regex scan em toda a tabela de tickets
  # - Lock granular no row do contador, não no row da organização
  # - Semanticamente idêntico: serializado por org, sem duplicatas
  def generate_ticket_id
    sql = Ticket.sanitize_sql_array([
      "INSERT INTO ticket_counters (organization_id, counter) VALUES (?, 1) " \
      "ON CONFLICT (organization_id) " \
      "DO UPDATE SET counter = ticket_counters.counter + 1 " \
      "RETURNING counter",
      organization_id
    ])
    num = self.class.connection.select_value(sql).to_i
    # Prefixo por empresa garante unicidade global do ID entre organizações.
    # Fallback "TK" apenas defensivo (organização sempre tem prefixo via validação).
    prefix = organization&.ticket_prefix.presence || "TK"
    self.id = "#{prefix}-#{format('%04d', num)}"
  end

  # ── Registra histórico de campos de associação (assignee, priority, category, queue) ──
  # Versão otimizada: preload em lote dos registros necessários antes do loop,
  # reduzindo de N×2 queries (find_by por campo/valor) para no máximo 4 queries totais
  # (uma por tipo, apenas se o tipo tiver campos alterados).
  def record_field_histories
    changed_fields = TRACKED_ASSOCIATIONS.keys & saved_changes.keys
    return if changed_fields.empty?

    actor = Current.user || assignee || requester

    # Coleta todos os IDs que precisam de resolução, agrupados por tipo
    user_ids = []; priority_ids = []; category_ids = []; queue_ids = []
    changed_fields.each do |field|
      old_id, new_id = saved_changes[field]
      case field
      when "assignee_id"  then user_ids     += [old_id, new_id]
      when "priority_id"  then priority_ids += [old_id, new_id]
      when "category_id"  then category_ids += [old_id, new_id]
      when "queue_id"     then queue_ids    += [old_id, new_id]
      end
    end

    # Batch load — 1 query por tipo, só se necessário
    users_map      = user_ids.any?     ? organization.users.where(id: user_ids.compact).index_by(&:id) : {}
    priorities_map = priority_ids.any? ? organization.priorities.where(id: priority_ids.compact).index_by(&:id) : {}
    categories_map = category_ids.any? ? organization.categories.where(id: category_ids.compact).index_by(&:id) : {}
    queues_map     = queue_ids.any?    ? organization.queues.where(id: queue_ids.compact).index_by(&:id) : {}

    changed_fields.each do |field|
      old_id, new_id = saved_changes[field]
      from_val, to_val = case field
                         when "assignee_id"
                           [ resolve_user_name(users_map, old_id),
                             resolve_user_name(users_map, new_id) ]
                         when "priority_id"
                           [ priorities_map[old_id]&.name, priorities_map[new_id]&.name ]
                         when "category_id"
                           [ categories_map[old_id]&.name, categories_map[new_id]&.name ]
                         when "queue_id"
                           [ queues_map[old_id]&.name, queues_map[new_id]&.name ]
                         end
      histories.create!(
        user:       actor,
        field:      field.sub("_id", ""),
        from_value: from_val,
        to_value:   to_val
      )
    end
  end

  def resolve_user_name(map, id)
    return nil unless id
    u = map[id]
    u ? "#{u.first_name} #{u.last_name}" : nil
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
    TicketBroadcastJob.perform_later(id, "ticket_created")
  end

  def broadcast_ticket_updated
    TicketBroadcastJob.perform_later(id, "ticket_updated")
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
