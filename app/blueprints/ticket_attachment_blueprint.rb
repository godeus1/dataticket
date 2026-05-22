class TicketAttachmentBlueprint < Blueprinter::Base
  identifier :id
  fields :filename, :content_type, :byte_size, :created_at

  association :user, blueprint: UserBlueprint, view: :summary

  # URL pré-assinada do S3 (expira em 1 hora). Nil em dev sem S3 configurado.
  field :download_url do |attachment|
    S3Uploader.presigned_url(attachment.storage_key) if attachment.storage_key.present?
  end
end
