class TicketBroadcastJob < ApplicationJob
  queue_as :default

  # Serializes and broadcasts the ticket summary over ActionCable.
  # Running this in a job keeps the Blueprinter rendering out of the
  # after_commit callback path, so the DB connection is released sooner.
  def perform(ticket_id, event)
    ticket = Ticket.includes(
      :requester, :assignee, :category, :priority, :queue, :tags, :co_assignees
    ).find_by(id: ticket_id)
    return unless ticket

    TicketsChannel.broadcast_to(
      ticket.organization,
      { event: event, ticket: TicketBlueprint.render_as_hash(ticket, view: :summary) }
    )
  end
end
