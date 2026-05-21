class QueueMembership < ApplicationRecord
  belongs_to :queue, class_name: "TicketQueue"
  belongs_to :user

  validates :queue_id, uniqueness: { scope: :user_id }
end
