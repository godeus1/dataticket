class QueueBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :description, :active, :created_at, :updated_at

  association :users, blueprint: UserBlueprint, view: :summary

  field :category_name do |queue|
    queue.category&.name
  end
end
