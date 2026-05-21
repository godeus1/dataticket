class Ticket < ApplicationRecord
  self.primary_key = "id"

  belongs_to :organization
  belongs_to :requester, class_name: "User", foreign_key: :requester_id
  belongs_to :assignee,  class_name: "User", foreign_key: :assignee_id, optional: true
  belongs_to :category,  optional: true
  belongs_to :priority,  optional: true
  belongs_to :queue,     class_name: "TicketQueue", optional: true

  has_many :comments,     class_name: "TicketComment",    foreign_key: :ticket_id, dependent: :destroy
  has_many :histories,    class_name: "TicketHistory",    foreign_key: :ticket_id, dependent: :destroy
  has_many :attachments,  class_name: "TicketAttachment", foreign_key: :ticket_id, dependent: :destroy
  has_many :notifications,                                foreign_key: :ticket_id, dependent: :nullify
  has_many :scheduled_days,                               foreign_key: :ticket_id, dependent: :destroy

  STATUSES = [
    "Não iniciado",
    "Triado, aguardando atendimento",
    "Em andamento",
    "Aguardando terceiros",
    "Resolvido",
    "Fechado",
    "Reaberto"
  ].freeze

  ALLOWED_TRANSITIONS = {
    "Não iniciado"                    => %w[Triado,\ aguardando\ atendimento Em\ andamento Fechado],
    "Triado, aguardando atendimento"  => ["Em andamento", "Aguardando terceiros", "Fechado"],
    "Em andamento"                    => ["Aguardando terceiros", "Resolvido", "Fechado"],
    "Aguardando terceiros"            => ["Em andamento", "Resolvido", "Fechado"],
    "Resolvido"                       => ["Reaberto", "Fechado"],
    "Fechado"                         => ["Reaberto"],
    "Reaberto"                        => ["Em andamento", "Triado, aguardando atendimento"]
  }.freeze

  validates :title,  presence: true, length: { maximum: 255 }
  validates :status, inclusion: { in: STATUSES }

  before_create :generate_ticket_id
  after_update  :record_status_history, if: :saved_change_to_status?
  after_update  :stamp_resolved_at,     if: :saved_change_to_status?

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

  def generate_ticket_id
    # Extrai o número da última TK da organização e incrementa
    last_num = organization.tickets
                           .where("id ~ ?", "^TK-\\d+$")
                           .maximum("CAST(SUBSTRING(id, 4) AS INTEGER)") || 0
    self.id = "TK-#{format("%04d", last_num + 1)}"
  end

  def record_status_history
    actor = assignee || requester
    histories.create!(
      user:       actor,
      field:      "status",
      from_value: saved_change_to_status.first,
      to_value:   saved_change_to_status.last
    )
  end

  def stamp_resolved_at
    if %w[Resolvido Fechado].include?(status) && resolved_at.nil?
      update_column(:resolved_at, Time.current)
    end
  end
end
