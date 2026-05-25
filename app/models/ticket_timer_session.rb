class TicketTimerSession < ApplicationRecord
  belongs_to :ticket
  belongs_to :user

  validates :started_at,    presence: true
  validates :stopped_at,    presence: true
  validates :duration_mins, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :chronological, -> { order(:started_at) }
end
