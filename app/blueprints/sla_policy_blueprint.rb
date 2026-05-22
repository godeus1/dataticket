class SlaPolicyBlueprint < Blueprinter::Base
  identifier :id

  fields :priority_id, :category_id,
         :response_hours, :resolve_hours,
         :active, :created_at, :updated_at

  field :priority_name do |policy|
    policy.priority&.name
  end

  field :category_name do |policy|
    policy.category&.name
  end
end
