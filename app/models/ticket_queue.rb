class TicketQueue < ApplicationRecord
  self.table_name = "queues"

  belongs_to :organization
  belongs_to :category, optional: true
  has_many :queue_memberships, foreign_key: :queue_id, dependent: :destroy
  has_many :users,   through: :queue_memberships
  has_many :tickets, foreign_key: :queue_id, dependent: :nullify

  validates :name, presence: true

  scope :active, -> { where(active: true) }
end
