module Api
  module V1
    module Articles
      # Anexos de artigos da Base de Conhecimento — mesmo modelo dos tickets
      # (máx. 3 arquivos de 5 MB, download autenticado).
      class AttachmentsController < ApplicationController
        include ActionController::DataStreaming

        before_action :set_article
        before_action :set_attachment, only: %i[destroy download]

        MAX_SIZE  = 5.megabytes
        MAX_COUNT = 3

        def index
          authorize @article, :show?
          attachments = @article.article_attachments.includes(:user).order(created_at: :asc)
          render json: ArticleAttachmentBlueprint.render_as_hash(attachments)
        end

        def create
          authorize @article, :update?

          file = params[:file]
          return render json: { error: "Arquivo não enviado" }, status: :unprocessable_entity unless file.present?
          return render json: { error: "Arquivo excede o limite de 5 MB" }, status: :unprocessable_entity if file.size > MAX_SIZE
          return render json: { error: "Limite de #{MAX_COUNT} anexos por artigo atingido" }, status: :unprocessable_entity if @article.article_attachments.count >= MAX_COUNT

          compressed = AttachmentCompressor.compress(
            file,
            content_type: file.content_type,
            filename:     file.original_filename
          )

          key    = S3Uploader.build_key("kb-#{@article.id}", compressed.filename)
          result = S3Uploader.upload(compressed.io, key: key, content_type: compressed.content_type)

          return render json: { error: "Falha no upload: #{result.error}" }, status: :unprocessable_entity unless result.success?

          attachment = @article.article_attachments.create!(
            filename:     compressed.filename,
            content_type: compressed.content_type,
            byte_size:    compressed.io.string.bytesize,
            storage_key:  result.key,
            user:         current_user
          )

          render json: ArticleAttachmentBlueprint.render_as_hash(attachment), status: :created
        end

        def download
          authorize @article, :show?

          if S3Uploader.enabled?
            url = S3Uploader.presigned_url(@attachment.storage_key)
            return render json: { error: "Arquivo não disponível" }, status: :not_found unless url.present?
            redirect_to url, allow_other_host: true
          else
            path = S3Uploader.local_path(@attachment.storage_key)

            storage_root = File.realpath(
              ENV.fetch("STORAGE_PATH", Rails.root.join("tmp", "attachments").to_s)
            )
            resolved = File.expand_path(path)
            unless resolved.start_with?(storage_root)
              Rails.logger.warn("[article_attachment_download] path traversal bloqueado: storage_key=#{@attachment.storage_key.inspect}")
              return render json: { error: "Arquivo não disponível" }, status: :forbidden
            end

            return render json: { error: "Arquivo não encontrado no servidor" }, status: :not_found unless File.exist?(resolved)

            send_file resolved,
              filename:    @attachment.filename,
              type:        @attachment.content_type,
              disposition: "attachment"
          end
        end

        def destroy
          authorize @article, :update?
          @attachment.destroy!
          head :no_content
        end

        private

        def set_article
          @article = @organization.articles.find(params[:article_id])
        end

        def set_attachment
          @attachment = @article.article_attachments.find(params[:id])
        end
      end
    end
  end
end
