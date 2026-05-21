class Category < ApplicationRecord
  belongs_to :organization
  has_many :tickets,  dependent: :nullify
  has_many :queues,   dependent: :nullify

  validates :name, presence: true
  validates :color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "deve ser um hex válido (#rrggbb)" }

  scope :active, -> { where(active: true) }
end
