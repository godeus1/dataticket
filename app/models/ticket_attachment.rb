class TicketAttachment < ApplicationRecord
  belongs_to :ticket, foreign_key: :ticket_id
  belongs_to :user

  validates :filename, presence: true
end
