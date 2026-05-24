# app/jobs/database_backup_job.rb
#
# Cria um dump completo do banco e:
#   1. Se S3 configurado  → envia para S3 (chave: backups/<timestamp>/dataticket.dump)
#   2. Se STORAGE_PATH    → salva no volume local (backups/<timestamp>/dataticket.dump)
#      mantendo os últimos 7 dias e deletando os mais antigos.
#   3. Se nenhum dos dois  → envia alerta por e-mail ao admin.
#
# Acionamento: agendado via config/recurring.yml (diário às 03:00 UTC).
# Execução manual: DatabaseBackupJob.perform_later
class DatabaseBackupJob < ApplicationJob
  queue_as :default

  KEEP_BACKUPS = 7  # número de backups locais a manter

  def perform
    if S3Uploader.enabled?
      backup_to_s3
    elsif local_storage_available?
      backup_to_local
    else
      warn_no_storage
    end
  end

  private

  # ── S3 ───────────────────────────────────────────────────────────────────────
  def backup_to_s3
    with_temp_dump do |dump_path, timestamp|
      key    = "backups/#{timestamp}/dataticket.dump"
      result = S3Uploader.upload(File.open(dump_path, "rb"), key: key, content_type: "application/octet-stream")

      if result.success?
        Rails.logger.info("[DatabaseBackupJob] Backup enviado para S3: #{key}")
      else
        Rails.logger.error("[DatabaseBackupJob] Falha no upload S3: #{result.error}")
        notify_admin_failure("Falha no upload do backup para S3: #{result.error}")
      end
    end
  end

  # ── Volume local ─────────────────────────────────────────────────────────────
  def backup_to_local
    timestamp  = Time.current.strftime("%Y%m%d_%H%M%S")
    backup_dir = File.join(storage_path, "backups", timestamp)
    FileUtils.mkdir_p(backup_dir)
    dump_path  = File.join(backup_dir, "dataticket.dump")

    begin
      run_pg_dump(dump_path)
      size_mb = (File.size(dump_path) / 1.megabyte.to_f).round(2)
      Rails.logger.info("[DatabaseBackupJob] Backup local salvo: #{dump_path} (#{size_mb} MB)")
      rotate_local_backups
    rescue => e
      Rails.logger.error("[DatabaseBackupJob] Falha no backup local: #{e.message}")
      FileUtils.rm_rf(backup_dir)
      notify_admin_failure("Falha no backup local do banco de dados: #{e.message}")
    end
  end

  # Remove backups mais antigos, mantendo apenas KEEP_BACKUPS
  def rotate_local_backups
    backup_root = File.join(storage_path, "backups")
    return unless Dir.exist?(backup_root)

    entries = Dir.glob(File.join(backup_root, "*")).select { |e| File.directory?(e) }.sort
    to_delete = entries[0...(entries.size - KEEP_BACKUPS)]
    to_delete.each do |dir|
      FileUtils.rm_rf(dir)
      Rails.logger.info("[DatabaseBackupJob] Backup antigo removido: #{dir}")
    end
  end

  # ── Sem armazenamento configurado ────────────────────────────────────────────
  def warn_no_storage
    msg = "O backup automático do banco de dados NÃO está sendo realizado porque " \
          "nenhum armazenamento foi configurado.\n\n" \
          "Opções:\n" \
          "  • Configure AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_S3_BUCKET e " \
          "AWS_REGION para envio ao S3.\n" \
          "  • Ou mantenha STORAGE_PATH configurado (volume Railway) para backup local " \
          "com retenção de #{KEEP_BACKUPS} dias."
    Rails.logger.warn("[DatabaseBackupJob] #{msg.split("\n").first}")
    notify_admin_failure(msg)
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────
  def with_temp_dump
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    dump_path = Rails.root.join("tmp", "db_backup_#{timestamp}.dump").to_s
    FileUtils.mkdir_p(File.dirname(dump_path))
    run_pg_dump(dump_path)
    yield dump_path, timestamp
  ensure
    FileUtils.rm_f(dump_path)
  end

  def run_pg_dump(path)
    db_url  = ENV.fetch("DATABASE_URL")
    success = system("pg_dump --format=custom --no-acl --no-owner \"#{db_url}\" -f \"#{path}\"")
    raise "pg_dump falhou (exit #{$?.exitstatus})" unless success
  end

  def storage_path
    ENV.fetch("STORAGE_PATH", Rails.root.join("tmp", "attachments").to_s)
  end

  def local_storage_available?
    storage_path.present?
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
