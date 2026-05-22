module Api
  module V1
    class ArticlesController < ApplicationController
      before_action :set_article, only: %i[show update destroy]

      def index
        authorize Article
        articles = @organization.articles.includes(:author).recent
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
        render json: ArticleBlueprint.render_as_hash(article), status: :created
      end

      def update
        authorize @article
        @article.update!(article_params)
        render json: ArticleBlueprint.render_as_hash(@article)
      end

      def destroy
        authorize @article
        @article.destroy!
        head :no_content
      end

      private

      def set_article
        @article = @organization.articles.includes(:author).find(params[:id])
      end

      def article_params
        params.require(:article).permit(:title, :body, :keywords, :published)
      end
    end
  end
end
