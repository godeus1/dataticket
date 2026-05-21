class UserBlueprint < Blueprinter::Base
  identifier :id

  fields :email, :first_name, :last_name, :role, :active,
         :avatar_initials, :avatar_color, :available_hours,
         :max_hours_per_ticket, :organization_id, :created_at

  field :full_name

  view :summary do
    fields :id, :first_name, :last_name, :email, :role, :avatar_initials, :avatar_color
    field :full_name
  end
end
