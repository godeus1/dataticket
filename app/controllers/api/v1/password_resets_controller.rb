module Api
  module V1
    class PasswordResetsController < ApplicationController
      skip_before_action :authenticate_user!, raise: false
      skip_before_action :set_organization,   raise: false
      skip_before_action :set_current_user,   raise: false
      skip_after_action  :verify_authorized,  raise: false

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

        unless user.active?
          render json: { error: "Conta inativa. Entre em contato com o administrador." },
                 status: :forbidden
          return
        end

        code = generate_code
        user.update_columns(
          reset_password_token:   Digest::SHA256.hexdigest(code),
          reset_password_sent_at: Time.current
        )
        begin
          PasswordResetMailer.reset_code(user, code).deliver_now
          Rails.logger.info "[password_reset] e-mail enviado com sucesso para #{user.email}"
        rescue ArgumentError => e
          # Credenciais não configuradas no Railway
          Rails.logger.error "[password_reset] credencial ausente: #{e.message}"
          render json: {
            error: "Credenciais de e-mail não configuradas no servidor. " \
                   "Configure MAILERSEND_API_KEY ou SMTP_USER + SMTP_PASS nas variáveis de ambiente do Railway."
          }, status: :service_unavailable
          return
        rescue => e
          Rails.logger.error "[password_reset] #{e.class}: #{e.message}"
          hint = case e.message
                 when /401/, /unauthorized/i then "API key inválida ou sem permissão."
                 when /422/, /unprocessable/i then "Domínio remetente não verificado no MailerSend."
                 when /535/, /authentication/i then "Usuário ou senha SMTP incorretos."
                 when /getaddrinfo/, /connection/i then "Servidor SMTP inacessível. Verifique SMTP_HOST e SMTP_PORT."
                 else e.message.truncate(120)
                 end
          render json: { error: "Falha ao enviar e-mail: #{hint}" },
                 status: :service_unavailable
          return
        end

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
        if password.length < 12
          render json: { error: "A senha deve ter pelo menos 12 caracteres." }, status: :unprocessable_entity
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
