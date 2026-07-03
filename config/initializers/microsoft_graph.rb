require "microsoft_graph_delivery_method"

ActionMailer::Base.add_delivery_method(
  :microsoft_graph,
  MicrosoftGraphDeliveryMethod,
  tenant_id:     ENV.fetch("MS_TENANT_ID", ""),
  client_id:     ENV.fetch("MS_CLIENT_ID", ""),
  client_secret: ENV.fetch("MS_CLIENT_SECRET", ""),
  sender:        ENV.fetch("MAIL_FROM", "")
)

# Retry automático para falhas TRANSITÓRIAS de envio (throttling 429
# "ApplicationThrottled", 5xx e timeouts de rede). Sem isso, e-mails enviados
# em rajada (ex.: SLA digest às 08:00, ou um reset de senha que caia junto)
# morriam na fila de falhas e o destinatário nunca recebia.
Rails.application.config.to_prepare do
  ActionMailer::MailDeliveryJob.retry_on(
    MicrosoftGraphDeliveryMethod::TransientError,
    wait: :polynomially_longer, attempts: 8, jitter: 0.3
  )
  ActionMailer::MailDeliveryJob.retry_on(
    Net::OpenTimeout, Net::ReadTimeout,
    wait: :polynomially_longer, attempts: 5, jitter: 0.3
  )
end
