class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "noreply@test-2p0347z36vylzdrn.mlsender.net")
  layout "mailer"

  after_action :log_delivery

  private

  def log_delivery
    to = message.to&.join(", ") || "(sem destinatário)"
    Rails.logger.info("[mailer] #{mailer_name}##{action_name} → #{to}")
  end
end
