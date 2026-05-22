class CustomFieldBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :field_type, :options, :required, :position, :active, :created_at
end
