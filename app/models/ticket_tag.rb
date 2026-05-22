class TicketTag < ApplicationRecord
  belongs_to :ticket
  belongs_to :tag

  validates :ticket_id, uniqueness: { scope: :tag_id }
end
