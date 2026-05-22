class CustomField < ApplicationRecord
  FIELD_TYPES = %w[text number date dropdown].freeze

  belongs_to :organization
  has_many :field_values, class_name: "TicketFieldValue", dependent: :destroy

  validates :name,       presence: true, length: { maximum: 100 }
  validates :field_type, inclusion: { in: FIELD_TYPES }
  validates :position,   numericality: { greater_than_or_equal_to: 0 }
  validate  :options_required_for_dropdown

  scope :active,  -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
  scope :required_fields, -> { active.where(required: true) }

  # Cast a raw string value to the appropriate type for validation
  def cast_value(raw)
    return nil if raw.blank?

    case field_type
    when "number"  then Float(raw)
    when "date"    then Date.parse(raw.to_s)
    when "dropdown"
      raise ArgumentError, "opção inválida: #{raw}" unless options.include?(raw.to_s)
      raw.to_s
    else
      raw.to_s
    end
  rescue ArgumentError, TypeError => e
    raise ArgumentError, "Campo '#{name}': #{e.message}"
  end

  private

  def options_required_for_dropdown
    if field_type == "dropdown" && Array(options).empty?
      errors.add(:options, "não pode ser vazio para campos do tipo dropdown")
    end
  end
end
