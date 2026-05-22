module Api
  module V1
    class CategoriesController < ApplicationController
      before_action :set_category, only: %i[show update destroy]

      def index
        authorize Category
        categories = @organization.categories.order(:name)
        render json: categories.as_json(only: %i[id name color active])
      end

      def show
        authorize @category
        render json: @category.as_json(only: %i[id name color active created_at updated_at])
      end

      def create
        authorize Category
        category = @organization.categories.new(category_params)
        category.save!
        render json: category.as_json(only: %i[id name color active]), status: :created
      end

      def update
        authorize @category
        @category.update!(category_params)
        render json: @category.as_json(only: %i[id name color active])
      end

      def destroy
        authorize @category
        @category.destroy!
        head :no_content
      end

      private

      def set_category
        @category = @organization.categories.find(params[:id])
      end

      def category_params
        params.require(:category).permit(:name, :color, :active)
      end
    end
  end
end
