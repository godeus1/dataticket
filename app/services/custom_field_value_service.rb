class CustomFieldValueService
  class ValidationError < StandardError; end

  # values_param: Array of { custom_field_id: X, value: "..." }
  #           OR Hash  { "custom_field_id" => "value", ... }
  def initialize(ticket, values_param)
    @ticket = ticket
    @values = normalize(values_param)
    @org    = ticket.organization
  end

  # Upserts values and validates required fields.
  # Raises CustomFieldValueService::ValidationError on failure.
  def save!
    ActiveRecord::Base.transaction do
      upsert_values!
      validate_required_fields!
    end
    true
  end

  private

  def upsert_values!
    @values.each do |custom_field_id, raw_value|
      field = @org.custom_fields.active.find_by(id: custom_field_id)
      next unless field

      # Will raise ArgumentError if value is wrong type/option
      field.cast_value(raw_value) if raw_value.present?

      fv = @ticket.field_values.find_or_initialize_by(custom_field_id: custom_field_id)
      fv.value = raw_value.presence
      fv.save!
    end
  end

  def validate_required_fields!
    missing = @org.custom_fields.required_fields.reject do |field|
      fv = @ticket.field_values.find_by(custom_field_id: field.id)
      fv&.value.present?
    end

    if missing.any?
      names = missing.map(&:name).join(", ")
      raise ValidationError, "Campos obrigatórios não preenchidos: #{names}"
    end
  end

  def normalize(param)
    case param
    when Array
      param.each_with_object({}) do |item, h|
        id  = item[:custom_field_id] || item["custom_field_id"]
        val = item[:value]           || item["value"]
        h[id.to_s] = val
      end
    when Hash
      param.transform_keys(&:to_s)
    else
      {}
    end
  end
end
