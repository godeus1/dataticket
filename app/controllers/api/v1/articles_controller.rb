module Api
  module V1
    class ArticlesController < ApplicationController
      before_action :set_article, only: %i[show update destroy]

      def index
        authorize Article
        articles = @organization.articles.includes(:author).recent
        articles = articles.published if params[:published] == "true"
        render json: articles.as_json(
          only: %i[id title body keywords published created_at updated_at],
          include: { author: { only: %i[id first_name last_name email] } }
        )
      end

      def show
        authorize @article
        render json: @article.as_json(
          only: %i[id title body keywords published created_at updated_at],
          include: { author: { only: %i[id first_name last_name email] } }
        )
      end

      def create
        authorize Article
        article = @organization.articles.new(article_params.merge(author: current_user))
        article.save!
        render json: article.as_json(only: %i[id title body keywords published]), status: :created
      end

      def update
        authorize @article
        @article.update!(article_params)
        render json: @article.as_json(only: %i[id title body keywords published])
      end

      def destroy
        authorize @article
        @article.destroy!
        head :no_content
      end

      private

      def set_article
        @article = @organization.articles.find(params[:id])
      end

      def article_params
        params.require(:article).permit(:title, :body, :keywords, :published)
      end
    end
  end
end
