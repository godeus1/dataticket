class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "onboarding@resend.dev")
  layout "mailer"

  after_action :log_delivery

  private

  def log_delivery
    to = message.to&.join(", ") || "(sem destinatário)"
    Rails.logger.info("[mailer] #{mailer_name}##{action_name} → #{to}")
  end

  def mail(headers = {}, &block)
    org       = Organization.first rescue nil
    from_addr = org&.smtp_user.presence || ENV.fetch("MAIL_FROM", "onboarding@resend.dev")
    headers[:from] ||= from_addr
    super
  end
end
