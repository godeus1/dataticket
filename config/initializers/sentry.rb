dsn = ENV["SENTRY_DSN"].presence

# Só inicializa Sentry quando DSN estiver configurado (produção)
return unless dsn

Sentry.init do |config|
  config.dsn                   = dsn
  config.breadcrumbs_logger    = [ :active_support_logger, :http_logger ]
  config.traces_sample_rate    = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.2").to_f
  config.profiles_sample_rate  = 0.0   # habilitar quando precisar de profiling

  # Não vazar dados sensíveis nos eventos
  config.send_default_pii      = false

  # Ambiente
  config.environment           = Rails.env
  config.enabled_environments  = %w[production staging]

  # Contexto extra em cada evento
  config.before_send = lambda do |event, _hint|
    # Remove parâmetros sensíveis do request
    event.request&.data&.delete("password")
    event.request&.data&.delete("token")
    event
  end
end
