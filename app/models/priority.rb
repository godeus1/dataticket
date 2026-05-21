class Priority < ApplicationRecord
  belongs_to :organization
  has_many :tickets, dependent: :nullify

  validates :name,      presence: true
  validates :sla_hours, numericality: { greater_than: 0 }
  validates :sla_days,  numericality: { greater_than: 0 }
  validates :color,     format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "deve ser um hex válido (#rrggbb)" }

  scope :active,   -> { where(active: true) }
  scope :ordered,  -> { order(:position) }
end
