module Api
  module V1
    module Tickets
      class AttachmentsController < ApplicationController
        # send_file não está disponível em API-only por padrão
        include ActionController::DataStreaming

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

          # Comprime imagens antes do upload
          compressed = AttachmentCompressor.compress(
            file,
            content_type: file.content_type,
            filename:     file.original_filename
          )

          key    = S3Uploader.build_key(@ticket.id, compressed.filename)
          result = S3Uploader.upload(compressed.io, key: key, content_type: compressed.content_type)

          return render json: { error: "Falha no upload: #{result.error}" }, status: :unprocessable_entity unless result.success?

          byte_size = compressed.io.string.bytesize

          attachment = @ticket.ticket_attachments.create!(
            filename:     compressed.filename,
            content_type: compressed.content_type,
            byte_size:    byte_size,
            storage_key:  result.key,
            user:         current_user
          )

          render json: TicketAttachmentBlueprint.render_as_hash(attachment), status: :created
        end

        # GET /api/v1/tickets/:ticket_id/attachments/:id/download
        def download
          authorize @attachment, :show?

          if S3Uploader.enabled?
            url = S3Uploader.presigned_url(@attachment.storage_key)
            return render json: { error: "Arquivo não disponível" }, status: :not_found unless url.present?
            redirect_to url, allow_other_host: true
          else
            path = S3Uploader.local_path(@attachment.storage_key)
            return render json: { error: "Arquivo não encontrado no servidor" }, status: :not_found unless File.exist?(path)

            send_file path,
              filename:    @attachment.filename,
              type:        @attachment.content_type,
              disposition: "attachment"
          end
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
