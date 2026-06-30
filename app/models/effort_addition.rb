class EffortAddition < ApplicationRecord
  belongs_to :ticket, foreign_key: :ticket_id
  belongs_to :user

  SOURCES = %w[manual triage reopen].freeze

  validates :hours, numericality: { greater_than: 0 }
  validates :source, inclusion: { in: SOURCES }

  scope :recent, -> { order(created_at: :desc) }
end
