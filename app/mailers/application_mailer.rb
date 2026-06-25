class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "noreply@test-2p0347z36vylzdrn.mlsender.net")
  # Reply-To aponta para a caixa que captura respostas (vira comentário no
  # ticket). Use MAIL_INBOX para apontar a uma caixa DEDICADA que efetivamente
  # recebe os e-mails e é lida via Graph (Mail.Read). Default = MAIL_FROM.
  default reply_to: ENV["MAIL_INBOX"].presence || ENV["MAIL_FROM"].presence
  layout "mailer"

  after_action :log_delivery

  private

  def log_delivery
    to = message.to&.join(", ") || "(sem destinatário)"
    Rails.logger.info("[mailer] #{mailer_name}##{action_name} → #{to}")
  end
end
