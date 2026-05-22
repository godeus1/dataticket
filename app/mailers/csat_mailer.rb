class CsatMailer < ApplicationMailer
  def survey(ticket)
    @ticket    = ticket
    @user      = ticket.requester
    @csat_url  = "#{ENV.fetch("FRONTEND_URL", "http://localhost:5173")}/csat/#{ticket.csat_token}"

    mail(
      to:      @user.email,
      subject: "[DataTicket] Como foi nosso atendimento? Ticket #{ticket.id}"
    )
  end
end
