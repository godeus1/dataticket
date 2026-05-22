module Api
  module V1
    class PasswordResetsController < ApplicationController
      skip_before_action :authenticate_user_from_token!
      skip_after_action  :verify_authorized

      CODE_EXPIRY = 15.minutes

      # POST /api/v1/password_reset/request
      # Gera código, salva no banco e envia por e-mail
      def request_reset
        email = params[:email].to_s.strip.downcase
        user  = User.find_by(email: email)

        unless user
          render json: { error: "E-mail não encontrado. Verifique o endereço ou contate o administrador." },
                 status: :not_found
          return
        end

        code = generate_code
        user.update_columns(
          reset_password_token:   Digest::SHA256.hexdigest(code),
          reset_password_sent_at: Time.current
        )
        PasswordResetMailer.reset_code(user, code).deliver_later

        render json: { message: "Código enviado para #{user.email}." }
      end

      # POST /api/v1/password_reset
      # Valida código e redefine a senha
      def create
        email    = params[:email].to_s.strip.downcase
        code     = params[:code].to_s.strip.upcase
        password = params[:password].to_s

        user = User.find_by(email: email)

        unless user&.reset_password_token.present?
          render json: { error: "Código inválido ou expirado." }, status: :unprocessable_entity
          return
        end

        # Verificar expiração
        if user.reset_password_sent_at < CODE_EXPIRY.ago
          user.update_columns(reset_password_token: nil, reset_password_sent_at: nil)
          render json: { error: "O código expirou. Solicite um novo." }, status: :unprocessable_entity
          return
        end

        # Verificar código
        unless ActiveSupport::SecurityUtils.secure_compare(
          user.reset_password_token,
          Digest::SHA256.hexdigest(code)
        )
          render json: { error: "Código inválido." }, status: :unprocessable_entity
          return
        end

        # Validar senha
        if password.length < 6
          render json: { error: "A senha deve ter pelo menos 6 caracteres." }, status: :unprocessable_entity
          return
        end

        # Atualizar senha e limpar token
        user.update!(password: password)
        user.update_columns(reset_password_token: nil, reset_password_sent_at: nil)

        render json: { message: "Senha redefinida com sucesso." }
      end

      private

      def generate_code
        # 6 caracteres alfanuméricos maiúsculos, sem caracteres ambíguos (0/O, 1/I/L)
        chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
        Array.new(6) { chars[SecureRandom.random_number(chars.length)] }.join
      end
    end
  end
end
