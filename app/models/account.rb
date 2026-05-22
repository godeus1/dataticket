class Account < ApplicationRecord
  PLANS = %w[standard enterprise].freeze

  has_many :organizations, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9\-]+\z/, message: "apenas letras minúsculas, números e hífens" }
  validates :plan, inclusion: { in: PLANS }

  before_validation :normalize_slug

  scope :active, -> { where(active: true) }

  private

  def normalize_slug
    self.slug = slug.to_s.downcase.strip.gsub(/\s+/, "-")
  end
end
