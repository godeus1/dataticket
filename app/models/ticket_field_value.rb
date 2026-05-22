class TicketFieldValue < ApplicationRecord
  belongs_to :ticket
  belongs_to :custom_field

  validates :ticket_id,       uniqueness: { scope: :custom_field_id }
  validates :custom_field_id, presence: true

  # Delegate type label for serialization
  delegate :name, :field_type, to: :custom_field, prefix: :field, allow_nil: true
end
