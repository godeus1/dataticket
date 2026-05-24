# app/jobs/jwt_cleanup_job.rb
#
# Remove tokens JWT expirados da tabela jwt_denylist.
# Tokens expirados não são mais capazes de autenticar — mantê-los no banco
# é desperdício de espaço e torna as consultas mais lentas ao longo do tempo.
#
# Acionamento: semanalmente às 04:00 UTC (config/recurring.yml).
# Execução manual: JwtCleanupJob.perform_later
class JwtCleanupJob < ApplicationJob
  queue_as :default

  # JWT expira em 24h (config/initializers/devise.rb). Removemos qualquer
  # registro inserido há mais de 25h para garantir que tokens válidos não
  # sejam removidos por corrida de condição (margem de 1h).
  EXPIRY_BUFFER = 25.hours

  def perform
    cutoff  = EXPIRY_BUFFER.ago
    deleted = JwtDenylist.where("created_at < ?", cutoff).delete_all
    Rails.logger.info("[JwtCleanupJob] #{deleted} tokens expirados removidos da denylist (cutoff: #{cutoff})")
  end
end
