class Organization < ApplicationRecord
  belongs_to :account, optional: true   # nil = standalone; present = managed by MSP

  has_many :users,             dependent: :destroy
  has_many :tickets,           dependent: :destroy
  has_many :categories,        dependent: :destroy
  has_many :priorities,        dependent: :destroy
  has_many :queues,            class_name: "TicketQueue", dependent: :destroy
  has_many :holidays,          dependent: :destroy
  has_many :articles,          dependent: :destroy
  has_many :audit_logs,        dependent: :destroy
  has_many :triage_rules,      dependent: :destroy
  has_many :webhook_endpoints, dependent: :destroy
  has_many :sla_policies,      dependent: :destroy
  has_many :tags,              dependent: :destroy
  has_many :custom_fields,     dependent: :destroy
  has_one  :sso_configuration, dependent: :destroy

  encrypts :smtp_pass

  # ── Tipos de e-mail, ligados/desligados POR EMPRESA (sem master global) ────
  # Cada empresa tem sua própria configuração em `email_settings` (jsonb).
  # Tipos CRÍTICOS (password_reset, welcome) SEMPRE enviam. Os demais são
  # controlados só pelo toggle por-tipo da empresa (default ON). NÃO existe
  # mais um master `emails_enabled` — a coluna está deprecada/sem efeito.
  EMAIL_TYPES = %w[
    password_reset welcome ticket_created ticket_assigned status_changed
    new_comment escalated csat sla_digest
  ].freeze
  CRITICAL_EMAIL_TYPES = %w[password_reset welcome].freeze

  # Regra de envio por tipo de e-mail:
  #   - Tipos CRÍTICOS (reset de senha, boas-vindas/credenciais): SEMPRE enviam,
  #     independentemente de qualquer toggle (são de segurança/acesso).
  #   - Demais tipos: controlados só pelo toggle por-tipo da empresa (default ON,
  #     configurável na tela "E-mails"). NÃO dependem mais de um master oculto —
  #     o antigo `emails_enabled` tinha default false e sem UI, o que fazia
  #     empresas novas não enviarem nenhum e-mail transacional.
  def email_type_enabled?(type)
    type = type.to_s
    return true if CRITICAL_EMAIL_TYPES.include?(type)

    email_settings.fetch(type, true) != false
  end

  # ── Tipos de evento que podem ser registrados (ou não) no Log de Auditoria ─
  # Cada empresa escolhe, via caixas de seleção, o que quer auditar. Default: ON.
  AUDIT_EVENT_TYPES = %w[
    ticket_created ticket_changed ticket_deleted ticket_restored kb_changed
  ].freeze

  def audit_event_enabled?(type)
    audit_settings.fetch(type.to_s, true) != false
  end

  # Funil único de criação de log de auditoria, respeitando o toggle do tipo.
  # Falha silenciosa: auditoria nunca deve quebrar a operação principal.
  def record_audit(event:, action:, entity:, entity_id: nil, changes: {}, user: nil)
    return unless audit_event_enabled?(event)

    audit_logs.create!(
      action:       action,
      entity:       entity,
      entity_id:    entity_id.to_s,
      changes_data: (changes || {}).compact,
      user:         user
    )
  rescue => e
    Rails.logger.error("[AuditLog] #{event}/#{action} — #{e.message}")
  end

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/, message: "apenas letras minúsculas, números e hífens" }

  # Prefixo dos IDs de ticket = 3 primeiras letras do nome (ex: Salvabras → SAL-00001,
  # Datatry → DAT-00001). Único por empresa para garantir unicidade global dos tickets.
  validates :ticket_prefix, presence: true,
            uniqueness: { case_sensitive: false },
            format: {
              with: /\A[A-Z][A-Z0-9]{1,9}\z/,
              message: "deve ter de 2 a 10 caracteres: letra maiúscula seguida de letras ou números"
            }

  before_validation :normalize_slug
  before_validation :normalize_ticket_prefix
  before_validation :derive_ticket_prefix

  private

  def normalize_slug
    self.slug = slug.to_s.downcase.strip.gsub(/\s+/, "-")
  end

  def normalize_ticket_prefix
    self.ticket_prefix = ticket_prefix.to_s.strip.upcase if ticket_prefix.present?
  end

  # Deriva o prefixo das 3 primeiras LETRAS do nome quando não informado
  # explicitamente (ex: "Salvabras" → "SAL", "Datatry" → "DAT"). Colisões entre
  # empresas com as mesmas 3 letras são barradas pelo índice único — nesse caso
  # o admin deve informar um prefixo alternativo manualmente.
  def derive_ticket_prefix
    return if ticket_prefix.present?

    letters = name.to_s.gsub(/[^a-zA-Z]/, "").upcase
    self.ticket_prefix = letters.present? ? letters[0, 3] : "ORG"
  end
end
