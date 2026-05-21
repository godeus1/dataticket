class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SMTP_USER", "noreply@dataticket.app")
  layout "mailer"
end
