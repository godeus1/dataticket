class Holiday < ApplicationRecord
  belongs_to :organization

  validates :name, :date, presence: true
  validates :kind, inclusion: { in: %w[Nacional Regional Customizado] }

  scope :upcoming, -> { where("date >= ?", Date.today).order(:date) }
end
