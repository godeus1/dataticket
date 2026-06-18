class TicketAttachmentBlueprint < Blueprinter::Base
  identifier :id
  fields :filename, :content_type, :byte_size, :created_at

  association :user, blueprint: UserBlueprint, view: :summary

  # Campos de lixeira (nulos para anexos ativos)
  field :deleted_at
  field :restorable_until, &:restorable_until
  association :deleted_by, blueprint: UserBlueprint, view: :summary, if: ->(_f, att, _o) { att.deleted_by.present? }

  # URL de download autenticada via endpoint da API.
  # O frontend usa fetch autenticado para baixar o arquivo.
  field :download_url do |attachment|
    next nil unless attachment.storage_key.present?

    if S3Uploader.enabled?
      S3Uploader.presigned_url(attachment.storage_key)
    else
      "/api/v1/tickets/#{attachment.ticket_id}/attachments/#{attachment.id}/download"
    end
  end
end
