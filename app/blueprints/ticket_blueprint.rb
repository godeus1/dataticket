class TicketBlueprint < Blueprinter::Base
  identifier :id

  # Summary view — used in index
  view :summary do
    fields :id, :title, :status, :created_at, :deadline, :resolved_at

    association :requester, blueprint: UserBlueprint, view: :summary
    association :assignee,  blueprint: UserBlueprint, view: :summary

    field :priority_name do |ticket|
      ticket.priority&.name
    end

    field :category_name do |ticket|
      ticket.category&.name
    end

    field :sla_expired do |ticket|
      ticket.sla_expired?
    end
  end

  # Full view — used in show/create/update
  view :full do
    include_view :summary

    fields :description, :updated_at

    association :comments, blueprint: TicketCommentBlueprint
    association :attachments, blueprint: TicketAttachmentBlueprint

    field :queue_name do |ticket|
      ticket.queue&.name
    end
  end
end
