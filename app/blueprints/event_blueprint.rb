class EventBlueprint < Blueprinter::Base
  identifier :id

  fields :aggregate_type, :aggregate_id, :event_type,
         :payload, :occurred_at, :version, :created_at

  association :actor, blueprint: UserBlueprint, view: :summary
end
