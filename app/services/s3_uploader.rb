# frozen_string_literal: true
# app/services/s3_uploader.rb
#
# Wrapper fino sobre aws-sdk-s3 para isolar a lógica de upload/download.
# Em desenvolvimento/teste (sem credenciais), cai para armazenamento local em tmp/.
require "aws-sdk-s3"

class S3Uploader
  BUCKET = ENV.fetch("AWS_S3_BUCKET", "dataticket-attachments")
  REGION = ENV.fetch("AWS_REGION",    "us-east-1")

  Result = Struct.new(:success?, :key, :error, keyword_init: true)

  # ── Upload ──────────────────────────────────────────────────────────────────
  def self.upload(io, key:, content_type: "application/octet-stream")
    if enabled?
      client.put_object(
        bucket:       BUCKET,
        key:          key,
        body:         io,
        content_type: content_type
      )
      Result.new(success?: true, key: key, error: nil)
    else
      local_save(io, key)
    end
  rescue Aws::S3::Errors::ServiceError => e
    Result.new(success?: false, key: nil, error: e.message)
  end

  # ── Presigned URL (1 hora por padrão) ───────────────────────────────────────
  def self.presigned_url(key, expires_in: 1.hour)
    return local_url(key) unless enabled?

    Aws::S3::Presigner.new(client: client)
                      .presigned_url(:get_object,
                                     bucket:     BUCKET,
                                     key:        key,
                                     expires_in: expires_in.to_i)
  end

  # ── Delete ──────────────────────────────────────────────────────────────────
  def self.delete(key)
    return unless key.present?

    if enabled?
      client.delete_object(bucket: BUCKET, key: key)
    else
      path = local_path(key)
      FileUtils.rm_f(path) if File.exist?(path)
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────────────────

  # S3 disponível apenas quando credenciais AWS presentes
  def self.enabled?
    ENV["AWS_ACCESS_KEY_ID"].present? && ENV["AWS_SECRET_ACCESS_KEY"].present?
  end

  def self.build_key(ticket_id, filename)
    safe = filename.gsub(/[^0-9A-Za-z.\-_]/, "_")
    "tickets/#{ticket_id}/#{SecureRandom.uuid}/#{safe}"
  end

  # Caminho absoluto no disco para armazenamento local.
  # Em produção usar STORAGE_PATH=/data/attachments (volume Railway).
  def self.local_path(key)
    base = ENV.fetch("STORAGE_PATH", Rails.root.join("tmp", "attachments").to_s)
    File.join(base, key)
  end

  private_class_method def self.client
    @client ||= Aws::S3::Client.new(
      region:            REGION,
      access_key_id:     ENV.fetch("AWS_ACCESS_KEY_ID"),
      secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY")
    )
  end

  private_class_method def self.local_save(io, key)
    dest = local_path(key)
    FileUtils.mkdir_p(File.dirname(dest))
    data = io.respond_to?(:read) ? io.read : io
    File.binwrite(dest, data)
    Result.new(success?: true, key: key, error: nil)
  end

  private_class_method def self.local_url(key)
    # Download é feito via endpoint autenticado; não há URL pública local
    nil
  end
end
