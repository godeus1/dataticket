class Tag < ApplicationRecord
  belongs_to :organization
  has_many :ticket_tags, dependent: :destroy
  has_many :tickets, through: :ticket_tags

  validates :name,  presence: true, length: { maximum: 50 }
  validates :name,  uniqueness: { scope: :organization_id, case_sensitive: false }
  validates :color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "deve ser um hex válido (#rrggbb)" }

  before_validation :normalize_name

  scope :ordered, -> { order(:name) }

  private

  def normalize_name
    self.name = name.to_s.strip.downcase
  end
end
