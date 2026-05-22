class WebhookEndpoint < ApplicationRecord
  EVENTS = %w[
    ticket.created
    ticket.updated
    ticket.status_changed
    ticket.assigned
    ticket.escalated
    ticket.closed
  ].freeze

  belongs_to :organization

  validates :name, presence: true, length: { maximum: 120 }
  validates :url,  presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
                                              message: "deve ser uma URL HTTP(S) válida" }
  validate  :events_must_be_valid

  scope :active,         -> { where(active: true) }
  scope :subscribed_to,  ->(event) { active.where("? = ANY(events)", event) }

  private

  def events_must_be_valid
    invalid = Array(events).reject { |e| EVENTS.include?(e) }
    errors.add(:events, "contém eventos inválidos: #{invalid.join(', ')}") if invalid.any?
  end
end
