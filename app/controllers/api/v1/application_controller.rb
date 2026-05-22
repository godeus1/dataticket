module Api
  module V1
    class ApplicationController < ActionController::API
      include Pundit::Authorization

      before_action :authenticate_user!
      before_action :set_organization
      before_action :set_current_user
      after_action  :verify_authorized, unless: :skip_authorization?

      rescue_from Pundit::NotAuthorizedError do
        render json: { error: "Não autorizado" }, status: :forbidden
      end

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "Recurso não encontrado" }, status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def set_organization
        if current_user.msp_admin? && request.headers["X-Organization-Id"].present?
          org_id = request.headers["X-Organization-Id"].to_i
          account = current_user.organization.account
          # msp_admin can only access orgs under the same account
          @organization = account&.organizations&.find_by(id: org_id) ||
                          raise(ActiveRecord::RecordNotFound, "Organização não encontrada nesta conta")
        else
          @organization = current_user.organization
        end
      end

      def set_current_user
        Current.user = current_user
      end

      def skip_authorization?
        false
      end
    end
  end
end
