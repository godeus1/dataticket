module Api
  module V1
    class SessionsController < Devise::SessionsController
      respond_to :json

      # Bloqueia o login quando a EMPRESA do usuário está inativa — ANTES da
      # autenticação Devise, para não emitir token. O msp_admin (super admin) é
      # isento: nunca fica trancado fora, mesmo que sua empresa-casa esteja inativa.
      def create
        email = params.dig(:user, :email).to_s.strip.downcase
        user  = User.find_for_database_authentication(email: email)
        if user && !user.msp_admin? && user.organization && !user.organization.active? &&
           user.valid_password?(params.dig(:user, :password).to_s)
          return render json: { error: "Empresa inativa. Contate o administrador." }, status: :unauthorized
        end
        super
      end

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

      # Devise 5 chama este método com o kwarg `non_navigational_status:`.
      # A assinatura sem argumentos causava ArgumentError (logout retornava 500).
      def respond_to_on_destroy(non_navigational_status: :no_content)
        if request.headers["Authorization"].present?
          head non_navigational_status
        else
          render json: { error: "Token não encontrado." }, status: :unauthorized
        end
      end
    end
  end
end
