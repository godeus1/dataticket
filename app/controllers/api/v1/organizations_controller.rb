module Api
  module V1
    class OrganizationsController < ApplicationController
      def show
        authorize @organization
        render json: org_json(@organization)
      end

      def update
        authorize @organization
        @organization.update!(organization_params)
        render json: org_json(@organization)
      end

      private

      def org_json(org)
        org.as_json(only: %i[id name slug timezone date_format emails_enabled
                             smtp_host smtp_port smtp_user created_at updated_at])
           .merge(
             attachments_enabled: S3Uploader.enabled?,
             smtp_pass_set: org.smtp_pass.present?
           )
      end

      def organization_params
        params.require(:organization).permit(
          :name, :timezone, :date_format,
          :emails_enabled,
          :smtp_host, :smtp_port, :smtp_user, :smtp_pass
        )
      end
    end
  end
end
