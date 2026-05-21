class TicketCommentBlueprint < Blueprinter::Base
  identifier :id
  fields :body, :kind, :created_at

  association :user, blueprint: UserBlueprint, view: :summary
end
