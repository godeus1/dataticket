# lib/tasks/backup.rake
#
# Uso:
#   rails db:backup                    # dump para tmp/backups/
#   rails db:backup S3=true            # força upload para S3 mesmo em dev
#   rails db:backup FILE=/tmp/my.dump  # path customizado
#
# No Railway: abrir o shell do serviço web e rodar `bundle exec rails db:backup`.

namespace :db do
  desc "Cria pg_dump do banco e (opcionalmente) envia para S3"
  task backup: :environment do
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    dump_path = ENV.fetch("FILE", Rails.root.join("tmp", "backups", "#{timestamp}.dump").to_s)

    FileUtils.mkdir_p(File.dirname(dump_path))

    db_url = ENV.fetch("DATABASE_URL") { ActiveRecord::Base.connection_db_config.url }

    puts "==> [#{Time.current}] Iniciando pg_dump..."
    success = system(%(pg_dump --format=custom --no-acl --no-owner "#{db_url}" -f "#{dump_path}"))

    abort "pg_dump falhou." unless success

    size_mb = (File.size(dump_path) / 1.megabyte.to_f).round(2)
    puts "    Dump criado: #{dump_path} (#{size_mb} MB)"

    if ENV["S3"] == "true" || S3Uploader.enabled?
      key    = "backups/manual/#{timestamp}/dataticket.dump"
      result = S3Uploader.upload(File.open(dump_path, "rb"), key: key, content_type: "application/octet-stream")

      if result.success?
        puts "    Upload S3 concluído: #{key}"
        FileUtils.rm_f(dump_path)
      else
        puts "    WARN: Upload S3 falhou (#{result.error}). Dump mantido em #{dump_path}."
      end
    else
      puts "    S3 não configurado — dump mantido localmente em #{dump_path}."
      puts "    Configure AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_S3_BUCKET para uploads automáticos."
    end

    puts "==> Backup concluído."
  end
end
