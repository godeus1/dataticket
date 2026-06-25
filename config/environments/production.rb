require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Anexos usam S3Uploader diretamente (aws-sdk-s3).
  # Variáveis necessárias no Railway: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY,
  # AWS_S3_BUCKET, AWS_REGION.  Sem elas, o upload falha com erro 422.
  # Active Storage não é usado para ticket_attachments.
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # connects_to removido: SolidQueue usa o banco principal (railway) em vez de
  # railway_queue, que nunca foi provisionado no Railway. Tabelas criadas via
  # migration 20260528000001_create_solid_queue_tables.
  config.active_job.queue_adapter = :solid_queue

  # ── E-mail ────────────────────────────────────────────────────────────────
  # Configure no Railway UMA das opções abaixo:
  #
  #   MailerSend (recomendado — sem bloqueio de porta):
  #     MAILERSEND_API_KEY=<sua chave>
  #     MAIL_FROM=noreply@seu-dominio-verificado.com
  #
  #   Gmail SMTP (alternativa):
  #     SMTP_HOST=smtp.gmail.com  SMTP_PORT=587
  #     SMTP_USER=seuemail@gmail.com
  #     SMTP_PASS=<Senha de app do Google — 16 caracteres>
  #     MAIL_FROM=seuemail@gmail.com
  #
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options   = {
    host: ENV.fetch("APP_HOST", "api.dataticket.app")
  }

  if ENV["MS_CLIENT_SECRET"].present? && ENV["MS_TENANT_ID"].present?
    # Microsoft Graph API (HTTP/443) — Office 365. Funciona no Railway, onde o
    # SMTP do Office 365 (smtp.office365.com:587) é bloqueado.
    config.action_mailer.delivery_method = :microsoft_graph
  elsif ENV["MAILERSEND_API_KEY"].present?
    config.action_mailer.delivery_method = :mailersend
  elsif ENV["SMTP_USER"].present? && ENV["SMTP_PASS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings   = {
      address:              ENV.fetch("SMTP_HOST",   "smtp.gmail.com"),
      port:                 ENV.fetch("SMTP_PORT",   "587").to_i,
      user_name:            ENV["SMTP_USER"],
      password:             ENV["SMTP_PASS"],
      authentication:       :plain,
      enable_starttls_auto: true,
      open_timeout:         5,
      read_timeout:         10,
    }
  else
    # Nenhuma credencial configurada — loga mas não quebra o boot
    config.action_mailer.delivery_method       = :smtp
    config.action_mailer.raise_delivery_errors = false
    warn "[mailer] ATENÇÃO: MAILERSEND_API_KEY e SMTP_USER/SMTP_PASS não configurados. E-mails não serão enviados."
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  api_host = ENV.fetch("APP_HOST", "web-production-03f8b.up.railway.app")
  config.hosts = [
    api_host,
    /.*\.railway\.app/,
    /.*\.vercel\.app/
  ]
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
