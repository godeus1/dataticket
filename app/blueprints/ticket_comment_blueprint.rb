class TicketCommentBlueprint < Blueprinter::Base
  identifier :id
  fields :body, :kind, :created_at, :author_name, :author_email, :source

  association :user, blueprint: UserBlueprint, view: :summary
end
