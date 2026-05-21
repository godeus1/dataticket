class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :ticket, foreign_key: :ticket_id, optional: true

  validates :title, presence: true
  validates :kind,  inclusion: { in: %w[create status comment assign triage] }, allow_nil: true

  scope :unread,  -> { where(read: false) }
  scope :recent,  -> { order(created_at: :desc) }
end
