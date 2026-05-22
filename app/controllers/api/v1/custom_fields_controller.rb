module Api
  module V1
    class CustomFieldsController < ApplicationController
      before_action :set_field, only: %i[show update destroy]

      def index
        authorize CustomField
        fields = policy_scope(CustomField).ordered
        render json: CustomFieldBlueprint.render_as_hash(fields)
      end

      def show
        authorize @custom_field
        render json: CustomFieldBlueprint.render_as_hash(@custom_field)
      end

      def create
        authorize CustomField
        field = @organization.custom_fields.create!(field_params)
        render json: CustomFieldBlueprint.render_as_hash(field), status: :created
      end

      def update
        authorize @custom_field
        @custom_field.update!(field_params)
        render json: CustomFieldBlueprint.render_as_hash(@custom_field)
      end

      def destroy
        authorize @custom_field
        @custom_field.destroy!
        head :no_content
      end

      private

      def set_field
        @custom_field = policy_scope(CustomField).find(params[:id])
      end

      def field_params
        params.require(:custom_field).permit(
          :name, :field_type, :required, :position, :active, options: []
        )
      end
    end
  end
end
