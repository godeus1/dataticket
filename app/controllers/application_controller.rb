class ApplicationController < ActionController::API
  include Pundit::Authorization
  include Auditable

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  private

  def current_organization
    current_user&.organization
  end

  def forbidden
    render json: { error: "Acesso negado." }, status: :forbidden
  end

  def not_found
    render json: { error: "Registro não encontrado." }, status: :not_found
  end
end
