module Api
  module V1
    class TagsController < ApplicationController
      before_action :set_tag, only: %i[show update destroy]

      def index
        authorize Tag
        tags = policy_scope(Tag).ordered
        render json: TagBlueprint.render_as_hash(tags)
      end

      def show
        authorize @tag
        render json: TagBlueprint.render_as_hash(@tag)
      end

      def create
        authorize Tag
        tag = @organization.tags.create!(tag_params)
        render json: TagBlueprint.render_as_hash(tag), status: :created
      end

      def update
        authorize @tag
        @tag.update!(tag_params)
        render json: TagBlueprint.render_as_hash(@tag)
      end

      def destroy
        authorize @tag
        @tag.destroy!
        head :no_content
      end

      private

      def set_tag
        @tag = policy_scope(Tag).find(params[:id])
      end

      def tag_params
        params.require(:tag).permit(:name, :color)
      end
    end
  end
end
