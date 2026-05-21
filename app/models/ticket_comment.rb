class TicketComment < ApplicationRecord
  belongs_to :ticket, foreign_key: :ticket_id
  belongs_to :user

  validates :body, presence: true
  validates :kind, inclusion: { in: %w[public internal] }

  scope :public_only,   -> { where(kind: "public") }
  scope :internal_only, -> { where(kind: "internal") }
end
