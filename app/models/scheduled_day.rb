class ScheduledDay < ApplicationRecord
  belongs_to :ticket, foreign_key: :ticket_id
  belongs_to :user

  validates :date,  presence: true
  validates :hours, numericality: { greater_than: 0, less_than_or_equal_to: 24 }
end
