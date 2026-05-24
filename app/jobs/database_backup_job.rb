# app/jobs/database_backup_job.rb
#
# Cria um dump completo do banco e envia para o S3 (quando configurado).
# Enquanto o S3 não está configurado, envia alerta por e-mail ao admin
# para que a situação não passe despercebida.
#
# Acionamento: agendado via config/recurring.yml (diário às 03:00).
# Também pode ser executado manualmente: rails db:backup (lib/tasks/backup.rake).
class DatabaseBackupJob < ApplicationJob
  queue_as :default

  # Tamanho máximo de dump aceito como anexo de e-mail (10 MB).
  # Acima disso apenas logamos e notificamos sem anexo.
  MAX_EMAIL_BYTES = 10.megabytes

  def perform
    if S3Uploader.enabled?
      backup_to_s3
    else
      warn_no_storage
    end
  end

  private

  # ── S3 path ──────────────────────────────────────────────────────────────────
  def backup_to_s3
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    key       = "backups/#{timestamp}/dataticket.dump"
    dump_path = Rails.root.join("tmp", "db_backup_#{timestamp}.dump").to_s

    begin
      run_pg_dump(dump_path)
      result = S3Uploader.upload(File.open(dump_path, "rb"), key: key, content_type: "application/octet-stream")

      if result.success?
        Rails.logger.info("[DatabaseBackupJob] Backup enviado para S3: #{key}")
      else
        Rails.logger.error("[DatabaseBackupJob] Falha no upload S3: #{result.error}")
        notify_admin_failure("Falha no upload do backup para S3: #{result.error}")
      end
    ensure
      FileUtils.rm_f(dump_path)
    end
  end

  # ── Sem S3: alerta por e-mail e log ─────────────────────────────────────────
  def warn_no_storage
    Rails.logger.warn("[DatabaseBackupJob] Backup NÃO realizado — S3 não configurado. Configure AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY e AWS_S3_BUCKET no Railway.")
    notify_admin_failure(
      "O backup automático do banco de dados NÃO está sendo realizado porque o " \
      "armazenamento S3 não foi configurado.\n\n" \
      "Configure as variáveis AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, " \
      "AWS_S3_BUCKET e AWS_REGION no serviço web do Railway para habilitar os backups automáticos."
    )
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────
  def run_pg_dump(path)
    db_url = ENV.fetch("DATABASE_URL")
    FileUtils.mkdir_p(File.dirname(path))
    success = system("pg_dump --format=custom --no-acl --no-owner \"#{db_url}\" -f \"#{path}\"")
    raise "pg_dump falhou (exit #{$?.exitstatus})" unless success
  end

  def notify_admin_failure(message)
    org   = Organization.first
    admin = org&.users&.where(role: "admin")&.order(:created_at)&.first
    return unless admin

    AdminMailer.backup_alert(admin, message).deliver_later
  rescue StandardError => e
    Rails.logger.error("[DatabaseBackupJob] Erro ao notificar admin: #{e.message}")
  end
end
