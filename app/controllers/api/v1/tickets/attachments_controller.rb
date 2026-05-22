module Api
  module V1
    module Tickets
      class AttachmentsController < ApplicationController
        before_action :set_ticket
        before_action :set_attachment, only: %i[destroy download]

        MAX_SIZE = 20.megabytes

        def index
          authorize TicketAttachment
          attachments = @ticket.ticket_attachments.includes(:user).order(created_at: :asc)
          render json: TicketAttachmentBlueprint.render_as_hash(attachments)
        end

        def create
          authorize TicketAttachment

          file = params[:file]
          return render json: { error: "Arquivo não enviado" }, status: :unprocessable_entity unless file.present?
          return render json: { error: "Arquivo excede o limite de 20 MB" }, status: :unprocessable_entity if file.size > MAX_SIZE

          key    = S3Uploader.build_key(@ticket.id, file.original_filename)
          result = S3Uploader.upload(file, key: key, content_type: file.content_type)

          return render json: { error: "Falha no upload: #{result.error}" }, status: :unprocessable_entity unless result.success?

          attachment = @ticket.ticket_attachments.create!(
            filename:     file.original_filename,
            content_type: file.content_type,
            byte_size:    file.size,
            storage_key:  result.key,
            user:         current_user
          )

          render json: TicketAttachmentBlueprint.render_as_hash(attachment), status: :created
        end

        # GET /api/v1/tickets/:ticket_id/attachments/:id/download
        # Redireciona para URL pré-assinada do S3 (ou 404 se não houver storage_key)
        def download
          authorize @attachment, :show?
          url = S3Uploader.presigned_url(@attachment.storage_key)
          return render json: { error: "Arquivo não disponível para download" }, status: :not_found unless url.present?

          redirect_to url, allow_other_host: true
        end

        def destroy
          authorize @attachment
          S3Uploader.delete(@attachment.storage_key)
          @attachment.destroy!
          head :no_content
        end

        private

        def set_ticket
          @ticket = policy_scope(Ticket).find(params[:ticket_id])
        end

        def set_attachment
          @attachment = @ticket.ticket_attachments.find(params[:id])
        end
      end
    end
  end
end
