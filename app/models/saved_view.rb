class SavedView < ApplicationRecord
  belongs_to :user
  belongs_to :organization

  validates :name, presence: true

  scope :recent, -> { order(created_at: :asc) }
end
