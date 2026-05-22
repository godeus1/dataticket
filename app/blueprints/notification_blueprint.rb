class NotificationBlueprint < Blueprinter::Base
  identifier :id
  fields :title, :body, :kind, :read, :ticket_id, :created_at
end
