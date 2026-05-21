require "devise/orm/active_record"  # carrega o ORM adapter — sem isso `devise` não existe nos models

Devise.setup do |config|
  config.mailer_sender = ENV.fetch("SMTP_USER", "noreply@dataticket.app")
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 12
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete

  config.jwt do |jwt|
    jwt.secret            = ENV.fetch("DEVISE_JWT_SECRET_KEY", "fallback-insecure-key-for-dev-only")
    jwt.dispatch_requests = [["POST", %r{^/api/v1/login$}]]
    jwt.revocation_requests = [["DELETE", %r{^/api/v1/logout$}]]
    jwt.expiration_time   = 6.hours.to_i
  end
end
