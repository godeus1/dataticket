class SlaPolicy < ApplicationRecord
  belongs_to :organization
  belongs_to :priority, optional: true
  belongs_to :category, optional: true

  validates :response_hours, :resolve_hours,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  validate :must_have_at_least_one_dimension

  scope :active,  -> { where(active: true) }

  # Most specific policy wins: category+priority > priority-only > category-only
  def self.find_for(organization:, priority:, category:)
    base = where(organization: organization).active

    # 1. Exact match
    exact = base.find_by(priority: priority, category: category)
    return exact if exact

    # 2. Priority only (category is nil)
    if priority
      by_priority = base.find_by(priority: priority, category: nil)
      return by_priority if by_priority
    end

    # 3. Category only (priority is nil)
    if category
      by_category = base.find_by(priority: nil, category: category)
      return by_category if by_category
    end

    nil
  end

  private

  def must_have_at_least_one_dimension
    if priority_id.nil? && category_id.nil?
      errors.add(:base, "precisa ter pelo menos uma prioridade ou categoria")
    end
  end
end
