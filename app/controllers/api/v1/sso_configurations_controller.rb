module Api
  module V1
    class SsoConfigurationsController < ApplicationController
      before_action :set_sso, only: %i[show update destroy]

      def show
        authorize @sso
        render json: SsoConfigurationBlueprint.render_as_hash(@sso)
      end

      def create
        authorize SsoConfiguration
        sso = @organization.create_sso_configuration!(sso_params)
        render json: SsoConfigurationBlueprint.render_as_hash(sso), status: :created
      end

      def update
        authorize @sso
        @sso.update!(sso_params)
        render json: SsoConfigurationBlueprint.render_as_hash(@sso)
      end

      def destroy
        authorize @sso
        @sso.destroy!
        head :no_content
      end

      private

      def set_sso
        @sso = @organization.sso_configuration ||
               raise(ActiveRecord::RecordNotFound, "SSO não configurado")
      end

      def sso_params
        params.require(:sso_configuration).permit(
          :idp_entity_id, :idp_sso_url, :idp_cert, :sp_entity_id,
          :name_id_format, :active
        )
      end
    end
  end
end
