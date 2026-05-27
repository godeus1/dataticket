class NotificationService
  def initialize(ticket)
    @ticket = ticket
  end

  def notify_assignee(assignee)
    return unless assignee

    assignee.notifications.create!(
      ticket:  @ticket,
      kind:    "assign",
      title:   "Ticket atribuído: #{@ticket.id}",
      body:    "Você foi atribuído ao ticket #{@ticket.id}: #{@ticket.title}"
    )
  end

  def notify_status_change(actor, old_status, new_status)
    recipients = relevant_users.reject { |u| u == actor }
    return if recipients.empty?

    bulk_insert(recipients,
      kind:  "status",
      title: "Status alterado — #{@ticket.id}",
      body:  "Status alterado de '#{old_status}' para '#{new_status}'"
    )
  end

  def notify_new_comment(actor)
    recipients = relevant_users.reject { |u| u == actor }
    return if recipients.empty?

    bulk_insert(recipients,
      kind:  "comment",
      title: "Novo comentário — #{@ticket.id}",
      body:  "Novo comentário no ticket: #{@ticket.title}"
    )
  end

  private

  def relevant_users
    [ @ticket.requester, @ticket.assignee ].compact.uniq
  end

  # insert_all em lote: 1 INSERT para N destinatários em vez de N inserts serializados.
  # Notification não possui callbacks after_create, portanto insert_all é seguro.
  def bulk_insert(users, kind:, title:, body:)
    now = Time.current
    Notification.insert_all(
      users.map do |user|
        {
          user_id:    user.id,
          ticket_id:  @ticket.id,
          kind:       kind,
          title:      title,
          body:       body,
          read:       false,
          created_at: now,
          updated_at: now
        }
      end
    )
  end
end
