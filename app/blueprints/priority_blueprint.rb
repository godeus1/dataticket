class PriorityBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :color, :sla_hours, :sla_days, :active, :position, :created_at, :updated_at
end
