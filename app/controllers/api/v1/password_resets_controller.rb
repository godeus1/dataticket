module Api
  module V1
    class PasswordResetsController < ApplicationController
      skip_before_action :authenticate_user_from_token!
      skip_after_action  :verify_authorized

      # POST /api/v1/password_reset
      # Público — redefine a senha pelo e-mail (fluxo "esqueci minha senha")
      def create
        user = User.find_by(email: params[:email].to_s.strip.downcase)

        unless user
          # Resposta genérica para não vazar se o e-mail existe
          render json: { message: "Se o e-mail estiver cadastrado, a senha foi redefinida." }
          return
        end

        unless params[:password].present? && params[:password].length >= 6
          render json: { error: "A senha deve ter pelo menos 6 caracteres." }, status: :unprocessable_entity
          return
        end

        user.update!(password: params[:password])
        render json: { message: "Senha redefinida com sucesso." }
      end
    end
  end
end
