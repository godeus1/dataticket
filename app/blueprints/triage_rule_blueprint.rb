class TriageRuleBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :keyword, :position, :active, :created_at, :updated_at

  field :category_id
  field :priority_id
  field :queue_id

  field :category_name do |rule|
    rule.category&.name
  end

  field :priority_name do |rule|
    rule.priority&.name
  end

  field :queue_name do |rule|
    rule.queue&.name
  end
end
