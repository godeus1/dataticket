module Api
  module V1
    class SessionsController < Devise::SessionsController
      respond_to :json

      private

      def respond_with(resource, _opts = {})
        # Guard: warden pode chamar respond_with com um recurso não autenticado
        # (sem id) quando a senha está errada. Retorna 401 explícito nesses casos.
        unless resource.persisted?
          render json: { error: "E-mail ou senha inválidos." }, status: :unauthorized
          return
        end

        # Bloqueia usuários inativos mesmo que a senha esteja correta.
        unless resource.active?
          render json: { error: "Conta inativa. Entre em contato com o administrador." }, status: :unauthorized
          return
        end

        render json: {
          user: {
            id:         resource.id,
            email:      resource.email,
            first_name: resource.first_name,
            last_name:  resource.last_name,
            role:       resource.role,
            active:     resource.active,
            avatar_initials: resource.avatar_initials,
            avatar_color:    resource.avatar_color,
            available_hours: resource.available_hours,
            organization_id: resource.organization_id
          }
        }, status: :ok
      end

      def respond_to_on_destroy
        if request.headers["Authorization"].present?
          render json: { message: "Logout realizado com sucesso." }, status: :ok
        else
          render json: { error: "Token não encontrado." }, status: :unauthorized
        end
      end
    end
  end
end
