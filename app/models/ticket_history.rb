class TicketHistory < ApplicationRecord
  belongs_to :ticket, foreign_key: :ticket_id
  belongs_to :user

  validates :field, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
