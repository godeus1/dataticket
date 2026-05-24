class TicketMailer < ApplicationMailer
  def created(ticket)
    @ticket = ticket
    @user   = ticket.requester
    @url    = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/tickets/#{ticket.id}"

    mail(
      to:      @user.email,
      subject: "[DataTicket] Ticket #{ticket.id} criado — #{ticket.title}"
    )
  end

  def status_changed(ticket, old_status)
    @ticket     = ticket
    @user       = ticket.requester
    @old_status = old_status
    @new_status = ticket.status
    @url        = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/tickets/#{ticket.id}"

    mail(
      to:      @user.email,
      subject: "[DataTicket] Status atualizado: #{ticket.id}"
    )
  end

  def assigned(ticket)
    @ticket  = ticket
    @user    = ticket.assignee
    @url     = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/tickets/#{ticket.id}"

    return unless @user

    mail(
      to:      @user.email,
      subject: "[DataTicket] Ticket atribuído a você: #{ticket.id}"
    )
  end

  def escalated(ticket, recipient)
    @ticket    = ticket
    @recipient = recipient
    @url       = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/tickets/#{ticket.id}"

    mail(
      to:      recipient.email,
      subject: "[DataTicket] ⚠️ Ticket escalado — SLA excedido: #{ticket.id}"
    )
  end

  def new_comment(ticket, comment, recipient)
    @ticket    = ticket
    @comment   = comment
    @recipient = recipient
    @url       = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/tickets/#{ticket.id}"

    mail(
      to:      recipient.email,
      subject: "[DataTicket] Novo comentário no ticket #{ticket.id}"
    )
  end

  def welcome(user, temp_password)
    @user          = user
    @login_url     = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/login"
    @temp_password = temp_password

    mail(
      to:      @user.email,
      subject: "DataTicket — Bem-vindo! Acesse sua conta"
    )
  end
end
