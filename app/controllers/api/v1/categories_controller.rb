module Api
  module V1
    class CategoriesController < ApplicationController
      before_action :set_category, only: %i[show update destroy]

      def index
        authorize Category
        categories = @organization.categories.order(:name)
        render json: CategoryBlueprint.render_as_hash(categories)
      end

      def show
        authorize @category
        render json: CategoryBlueprint.render_as_hash(@category)
      end

      def create
        authorize Category
        category = @organization.categories.new(category_params)
        category.save!
        render json: CategoryBlueprint.render_as_hash(category), status: :created
      end

      def update
        authorize @category
        @category.update!(category_params)
        render json: CategoryBlueprint.render_as_hash(@category)
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
