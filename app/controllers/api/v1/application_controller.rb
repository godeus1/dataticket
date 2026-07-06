module Api
  module V1
    class ApplicationController < ActionController::API
      include Pundit::Authorization
      include Auditable

      before_action :authenticate_user!
      before_action :set_organization
      before_action :set_current_user
      after_action  :verify_authorized, unless: :skip_authorization?

      # ── Tratamento de erros padronizado ──────────────────────────────────────
      #
      # Formato único em toda a API:
      #   Erro simples:     { "error": "mensagem" }
      #   Erro de validação: { "error": "Validação falhou", "details": ["campo X é inválido"] }
      #   Erro interno:     { "error": "Erro interno", "code": "internal_error" }
      #
      rescue_from Pundit::NotAuthorizedError do
        render_error "Você não tem permissão para realizar esta ação.", status: :forbidden, code: "forbidden"
      end

      rescue_from Pundit::AuthorizationNotPerformedError do
        render_error "Autorização não verificada.", status: :forbidden, code: "authorization_not_performed"
      end

      rescue_from ActiveRecord::RecordNotFound do |e|
        resource = e.model.present? ? e.model.underscore.humanize : "Recurso"
        render_error "#{resource} não encontrado.", status: :not_found, code: "not_found"
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render_validation_error e.record.errors.full_messages
      end

      rescue_from ActiveRecord::RecordNotUnique do
        render_error "Registro duplicado.", status: :conflict, code: "conflict"
      end

      rescue_from ActiveRecord::InvalidForeignKey do
        render_error "Não é possível excluir: o registro ainda é usado por outros dados.", status: :conflict, code: "in_use"
      end

      rescue_from ActionController::ParameterMissing do |e|
        render_error "Parâmetro obrigatório ausente: #{e.param}.", status: :bad_request, code: "missing_parameter"
      end

      rescue_from ArgumentError do |e|
        render_error e.message, status: :unprocessable_entity, code: "invalid_argument"
      end

      private

      # ── Helpers de resposta ────────────────────────────────────────────────

      # Renderiza erro simples.
      # Exemplo: render_error "Não encontrado", status: :not_found
      def render_error(message, status: :unprocessable_entity, code: nil)
        payload = { error: message }
        payload[:code] = code if code.present?
        render json: payload, status: status
      end

      # Renderiza erros de validação do ActiveRecord com lista de detalhes.
      # Exemplo: render_validation_error record.errors.full_messages
      def render_validation_error(messages, status: :unprocessable_entity)
        render json: {
          error:   "Validação falhou.",
          details: Array(messages)
        }, status: status
      end

      # ── Contexto de request ────────────────────────────────────────────────

      # Resolve a empresa EFETIVA da requisição e publica em Current.organization,
      # que é a única fonte de verdade de tenancy (controllers E Pundit Scopes).
      #
      # Regra de segurança: SOMENTE msp_admin pode trocar de empresa, e apenas
      # entre organizações da MESMA conta. Qualquer outro papel ignora o header
      # X-Organization-Id e fica preso à própria organização (anti-spoofing).
      def set_organization
        @organization = resolve_effective_organization
        Current.organization = @organization
      end

      def resolve_effective_organization
        if current_user.msp_admin? && request.headers["X-Organization-Id"].present?
          org_id  = request.headers["X-Organization-Id"].to_i
          account = current_user.organization.account
          # msp_admin só acessa orgs da mesma conta
          account&.organizations&.find_by(id: org_id) ||
            raise(ActiveRecord::RecordNotFound, "Organização não encontrada nesta conta")
        else
          current_user.organization
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
