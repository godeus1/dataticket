class TicketBlueprint < Blueprinter::Base
  identifier :id

  # Summary view — used in index
  view :summary do
    fields :id, :title, :status, :ticket_type, :escalated, :created_at, :deadline, :resolved_at

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

    association :tags, blueprint: TagBlueprint
  end

  # Full view — used in show/create/update
  view :full do
    include_view :summary

    fields :description, :updated_at, :csat_score, :csat_comment, :escalated_at

    association :comments,      blueprint: TicketCommentBlueprint
    association :attachments,   blueprint: TicketAttachmentBlueprint
    association :field_values,  blueprint: TicketFieldValueBlueprint

    field :queue_name do |ticket|
      ticket.queue&.name
    end
  end
end
