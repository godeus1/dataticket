class Category < ApplicationRecord
  belongs_to :organization
  has_many :tickets,  dependent: :nullify
  has_many :queues,   class_name: "TicketQueue", dependent: :nullify
  # Sem estes, o destroy estourava violação de FK (500) e a exclusão de
  # categoria "sem tickets" nunca funcionava:
  has_many :articles,     dependent: :nullify   # artigo continua, sem categoria
  has_many :sla_policies, dependent: :destroy   # política específica da categoria perde o sentido
  has_many :triage_rules, dependent: :destroy   # idem

  validates :name, presence: true
  validates :color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "deve ser um hex válido (#rrggbb)" }

  scope :active, -> { where(active: true) }
end
