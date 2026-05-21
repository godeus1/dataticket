class Organization < ApplicationRecord
  has_many :users,       dependent: :destroy
  has_many :tickets,     dependent: :destroy
  has_many :categories,  dependent: :destroy
  has_many :priorities,  dependent: :destroy
  has_many :queues,      class_name: "TicketQueue", dependent: :destroy
  has_many :holidays,    dependent: :destroy
  has_many :articles,    dependent: :destroy
  has_many :audit_logs,  dependent: :destroy

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/, message: "apenas letras minúsculas, números e hífens" }

  before_validation :normalize_slug

  private

  def normalize_slug
    self.slug = slug.to_s.downcase.strip.gsub(/\s+/, "-")
  end
end
