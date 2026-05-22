class Event < ApplicationRecord
  # Known event types — not exhaustive, new ones can be added without migration
  TYPES = %w[
    ticket.created
    ticket.updated
    ticket.status_changed
    ticket.triaged
    ticket.assigned
    ticket.escalated
    ticket.closed
    ticket.reopened
    ticket.comment_added
    user.created
    user.role_changed
    user.deactivated
    sla.breached
  ].freeze

  belongs_to :actor,        class_name: "User", optional: true
  belongs_to :organization

  validates :aggregate_type, presence: true
  validates :aggregate_id,   presence: true
  validates :event_type,     presence: true
  validates :occurred_at,    presence: true
  validates :organization,   presence: true

  # Events are immutable — no updates or deletes
  before_update { raise ActiveRecord::ReadOnlyRecord, "Events são imutáveis" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Events são imutáveis" }

  scope :for_aggregate, ->(type, id) { where(aggregate_type: type, aggregate_id: id.to_s) }
  scope :recent,        -> { order(occurred_at: :desc) }
  scope :chronological, -> { order(:occurred_at, :version) }
  scope :by_type,       ->(t) { where(event_type: t) }
  scope :in_period,     ->(from, to) { where(occurred_at: from..to) }
end
