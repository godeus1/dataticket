class SlaDigestMailer < ApplicationMailer
  def daily(user, expired_tickets, expiring_today)
    @user           = user
    @expired        = expired_tickets
    @expiring_today = expiring_today
    @url            = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/tickets"

    headers["List-Unsubscribe"] = "<mailto:#{ENV.fetch('SMTP_USER', 'noreply@dataticket.app')}?subject=unsubscribe>"
    headers["Precedence"]       = "bulk"

    mail(
      to:      @user.email,
      subject: "[DataTicket] Resumo SLA — #{Date.current.strftime('%d/%m/%Y')}"
    )
  end
end
