class InboundEmailPollJob < ApplicationJob
  queue_as :default

  # Verifica a caixa de entrada e converte respostas de e-mail em comentários.
  # No-op seguro quando o Microsoft Graph não está configurado.
  def perform
    InboundEmailService.poll!
  end
end
