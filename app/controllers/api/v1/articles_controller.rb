module Api
  module V1
    class ArticlesController < ApplicationController
      before_action :set_article, only: %i[show update destroy]

      def index
        authorize Article
        articles = @organization.articles.includes(:author, :article_attachments).recent
        articles = articles.published if params[:published] == "true"
        render json: ArticleBlueprint.render_as_hash(articles)
      end

      def show
        authorize @article
        render json: ArticleBlueprint.render_as_hash(@article)
      end

      def create
        authorize Article
        article = @organization.articles.new(article_params.merge(author: current_user))
        article.save!
        audit!(
          event:     "kb_changed",
          action:    "Artigo KB criado",
          entity:    "Base de Conhecimento",
          entity_id: article.id,
          changes:   { titulo: article.title, publicado: article.published ? "Sim" : "Não" }
        )
        render json: ArticleBlueprint.render_as_hash(article), status: :created
      end

      def update
        authorize @article
        old_title     = @article.title
        old_published = @article.published
        @article.update!(article_params)
        changes = { titulo: @article.title }
        changes[:titulo_anterior] = old_title if old_title != @article.title
        changes[:publicado] = @article.published ? "Sim" : "Não" if old_published != @article.published
        audit!(
          event:     "kb_changed",
          action:    "Artigo KB atualizado",
          entity:    "Base de Conhecimento",
          entity_id: @article.id,
          changes:   changes
        )
        render json: ArticleBlueprint.render_as_hash(@article)
      end

      def destroy
        authorize @article
        audit!(
          event:     "kb_changed",
          action:    "Artigo KB excluído",
          entity:    "Base de Conhecimento",
          entity_id: @article.id,
          changes:   { titulo: @article.title }
        )
        @article.destroy!
        head :no_content
      end

      private

      def set_article
        @article = @organization.articles.includes(:author, :article_attachments).find(params[:id])
      end

      def article_params
        params.require(:article).permit(:title, :body, :keywords, :published, :category_id)
      end
    end
  end
end
