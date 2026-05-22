class TriageRule < ApplicationRecord
  belongs_to :organization
  belongs_to :category, optional: true
  belongs_to :priority, optional: true
  belongs_to :queue, class_name: "TicketQueue", optional: true

  validates :name,    presence: true, length: { maximum: 120 }
  validates :keyword, presence: true, length: { maximum: 120 }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  scope :active,  -> { where(active: true) }
  scope :ordered, -> { order(:position) }
end
