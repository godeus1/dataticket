class TicketBlueprint < Blueprinter::Base
  identifier :id

  # Summary view — used in index
  view :summary do
    fields :id, :title, :status, :ticket_type, :escalated, :created_at, :deadline, :resolved_at,
           :priority_id, :category_id, :queue_id, :effort_estimated, :effort_used, :triaged

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

    field :scheduled_days do |ticket|
      ticket.scheduled_days.map { |sd| { date: sd.date.to_s, hours: sd.hours, user_id: sd.user_id } }
    end
  end

  # Full view — used in show/create/update
  view :full do
    include_view :summary

    fields :description, :updated_at, :csat_score, :csat_comment, :escalated_at,
           :deleted_at, :deleted_by_id

    association :comments,      blueprint: TicketCommentBlueprint
    association :attachments,   blueprint: TicketAttachmentBlueprint
    association :field_values,  blueprint: TicketFieldValueBlueprint
    association :co_assignees,  blueprint: UserBlueprint, view: :summary

    field :queue_name do |ticket|
      ticket.queue&.name
    end

    field :timer_sessions do |ticket|
      next [] unless ActiveRecord::Base.connection.table_exists?(:ticket_timer_sessions)

      ticket.timer_sessions.includes(:user).chronological.map do |s|
        {
          id:            s.id,
          started_at:    s.started_at,
          stopped_at:    s.stopped_at,
          duration_mins: s.duration_mins,
          user_id:       s.user_id,
          user_name:     s.user&.full_name,
        }
      end
    end
  end

  # Trash view — for admin trash listing
  view :trash do
    include_view :summary
    fields :deleted_at, :deleted_by_id
    field :deleted_by_name do |ticket|
      ticket.deleted_by_id ? User.find_by(id: ticket.deleted_by_id)&.full_name : nil
    end
    field :days_until_purge do |ticket|
      ticket.deleted_at ? [30 - (Time.current - ticket.deleted_at).to_i / 86400, 0].max : nil
    end
  end
end
