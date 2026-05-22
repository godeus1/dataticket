module Api
  module V1
    class OrganizationsController < ApplicationController
      def show
        authorize @organization
        render json: @organization.as_json(
          only: %i[id name slug timezone date_format created_at updated_at]
        )
      end

      def update
        authorize @organization
        @organization.update!(organization_params)
        render json: @organization.as_json(
          only: %i[id name slug timezone date_format created_at updated_at]
        )
      end

      private

      def organization_params
        params.require(:organization).permit(:name, :timezone, :date_format)
      end
    end
  end
end
