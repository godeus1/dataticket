class CategoryBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :color, :active, :created_at, :updated_at
end
