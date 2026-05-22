require_relative "jwt_denylist"  # garante que JwtDenylist é carregado antes de User

class User < ApplicationRecord
  devise :database_authenticatable, :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist

  belongs_to :organization
  has_many :assigned_tickets,  class_name: "Ticket", foreign_key: :assignee_id,  dependent: :nullify
  has_many :requested_tickets, class_name: "Ticket", foreign_key: :requester_id, dependent: :restrict_with_error
  has_many :notifications,     dependent: :destroy
  has_many :audit_logs,        dependent: :nullify
  has_many :queue_memberships, dependent: :destroy
  has_many :queues,            through: :queue_memberships, class_name: "TicketQueue", source: :queue
  has_many :ticket_comments,   dependent: :nullify
  has_many :authored_articles, class_name: "Article", foreign_key: :author_id, dependent: :nullify

  validates :email, presence: true,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            uniqueness: { scope: :organization_id, message: "já está em uso nesta organização", case_sensitive: false }
  validates :first_name, :last_name, presence: true
  ROLES = %w[admin analyst user msp_admin].freeze
  validates :role, inclusion: { in: ROLES }
  validates :available_hours,      numericality: { greater_than: 0, less_than_or_equal_to: 24 }
  validates :max_hours_per_ticket, numericality: { greater_than: 0 }

  before_validation :normalize_email
  before_create     :generate_jti

  scope :active,     -> { where(active: true) }
  scope :staff,      -> { where(role: %w[admin analyst]) }
  scope :admins,     -> { where(role: "admin") }
  scope :analysts,   -> { where(role: "analyst") }
  scope :msp_admins, -> { where(role: "msp_admin") }

  def msp_admin? = role == "msp_admin"

  def full_name
    "#{first_name} #{last_name}"
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end

  def generate_jti
    self.jti ||= SecureRandom.uuid
  end
end
