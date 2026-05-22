class HolidayBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :date, :kind, :recurring, :active, :created_at, :updated_at
end
