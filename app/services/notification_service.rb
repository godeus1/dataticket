class NotificationService
  def initialize(ticket)
    @ticket = ticket
  end

  def notify_assignee(assignee)
    return unless assignee

    assignee.notifications.create!(
      ticket:  @ticket,
      kind:    "assignment",
      title:   "Ticket atribuído: #{@ticket.id}",
      body:    "Você foi atribuído ao ticket #{@ticket.id}: #{@ticket.title}"
    )
  end

  def notify_status_change(actor, old_status, new_status)
    recipients = relevant_users.reject { |u| u == actor }
    recipients.each do |user|
      user.notifications.create!(
        ticket:  @ticket,
        kind:    "status_change",
        title:   "Status alterado — #{@ticket.id}",
        body:    "Status alterado de '#{old_status}' para '#{new_status}'"
      )
    end
  end

  def notify_new_comment(actor)
    recipients = relevant_users.reject { |u| u == actor }
    recipients.each do |user|
      user.notifications.create!(
        ticket:  @ticket,
        kind:    "new_comment",
        title:   "Novo comentário — #{@ticket.id}",
        body:    "Novo comentário no ticket: #{@ticket.title}"
      )
    end
  end

  private

  def relevant_users
    [@ticket.requester, @ticket.assignee].compact.uniq
  end
end
