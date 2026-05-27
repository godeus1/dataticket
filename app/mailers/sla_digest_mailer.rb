class SlaDigestMailer < ApplicationMailer
  # Recebe IDs em vez de objetos AR para minimizar payload serializado no job queue.
  # Os dados são carregados frescos no momento da execução do mailer.
  def daily(user_id, org_id, expired_ids, expiring_ids)
    @user           = User.find(user_id)
    org             = Organization.find(org_id)
    @expired        = org.tickets.where(id: expired_ids).includes(:priority)
    @expiring_today = org.tickets.where(id: expiring_ids).includes(:priority)
    @url            = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5173')}/tickets"

    headers["List-Unsubscribe"] = "<mailto:#{ENV.fetch('SMTP_USER', 'noreply@dataticket.app')}?subject=unsubscribe>"
    headers["Precedence"]       = "bulk"

    mail(
      to:      @user.email,
      subject: "[DataTicket] Resumo SLA — #{Date.current.strftime('%d/%m/%Y')}"
    )
  end
end
