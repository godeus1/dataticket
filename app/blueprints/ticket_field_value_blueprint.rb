class TicketFieldValueBlueprint < Blueprinter::Base
  identifier :id
  fields :value, :created_at, :updated_at

  field :custom_field_id
  field :field_name,  &:field_name
  field :field_type,  &:field_type
end
