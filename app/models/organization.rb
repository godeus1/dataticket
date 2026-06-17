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
