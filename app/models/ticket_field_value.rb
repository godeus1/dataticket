class TicketFieldValue < ApplicationRecord
  belongs_to :ticket
  belongs_to :custom_field

  validates :ticket_id,       uniqueness: { scope: :custom_field_id }
  validates :custom_field_id, presence: true

  # Delega rótulos do campo para serialização.
  # `name` recebe o prefixo (→ field_name) para não colidir com outros atributos;
  # `field_type` é delegado SEM prefixo (o prefixo geraria field_field_type, que o
  # blueprint não conhece → NoMethodError ao renderizar tickets com campos custom).
  delegate :name, to: :custom_field, prefix: :field, allow_nil: true
  delegate :field_type, to: :custom_field, allow_nil: true
end
