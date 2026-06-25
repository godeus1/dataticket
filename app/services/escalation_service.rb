# frozen_string_literal: true
# Escala um ticket cujo SLA passou de 120% do prazo sem resolucao.
# Acoes: bump de prioridade (se possivel), notificacao a admins + assignee,
# registro em TicketHistory e flag escalated = true.

class EscalationService
  def initialize(ticket)
    @ticket = ticket
    @org    = ticket.organization
  end

  def escalate
    ActiveRecord::Base.transaction do
      @ticket.update!(escalated: true, escalated_at: Time.current)

      @ticket.histories.create!(
        user:       system_actor,
        field:      "escalation",
        from_value: nil,
        to_value:   "Escalado automaticamente — SLA excedido em #{sla_exceeded_percent}%"
      )

      notify_stakeholders
    end
  end

  private

  def sla_exceeded_percent
    return 0 unless @ticket.deadline.present?
    sla_duration = @ticket.deadline - @ticket.created_at
    return 0 unless sla_duration > 0
    elapsed = Time.current - @ticket.created_at
    (((elapsed / sla_duration) - 1) * 100).round
  end

  def system_actor
    @org.users.admins.first || @org.users.managers.first || @ticket.requester
  end

  def notify_stakeholders
    recipients = []
    recipients << @ticket.assignee if @ticket.assignee.present?
    # Notifica admins e managers pois ambos têm visibilidade total
    recipients += @org.users.where(role: %w[admin manager]).to_a
    recipients = recipients.uniq

    return if recipients.empty?

    # Bulk insert — 1 INSERT para todos os destinatários em vez de N inserts serializados
    now = Time.current
    pct = sla_exceeded_percent
    Notification.insert_all(
      recipients.map do |user|
        {
          user_id:    user.id,
          ticket_id:  @ticket.id,
          kind:       "status",
          title:      "Ticket escalado — #{@ticket.id}",
          body:       "SLA excedido em #{pct}%. Ticket: #{@ticket.title}",
          read:       false,
          created_at: now,
          updated_at: now
        }
      end
    )

    return unless @org.email_type_enabled?("escalated")

    recipients.each do |user|
      TicketMailer.escalated(@ticket, user).deliver_later
    rescue => e
      Rails.logger.error("[escalation_email] falha ao notificar #{user.email}: #{e.message}")
    end
  end
end
