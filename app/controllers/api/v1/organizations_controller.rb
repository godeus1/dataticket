module Api
  module V1
    class OrganizationsController < ApplicationController
      # GET /organizations — empresas que o usuário atual pode acessar.
      #   msp_admin → todas as empresas da sua conta (para o seletor de empresa)
      #   demais    → apenas a própria empresa
      def index
        authorize Organization
        render json: accessible_organizations.order(:name).map { |o| org_summary(o) }
      end

      # POST /organizations — cria uma nova empresa sob a conta do msp_admin,
      # com um seed mínimo (prioridades + categoria) para já nascer utilizável.
      def create
        authorize Organization, :create?
        account = current_user.organization.account
        org = Organization.new(create_org_params.merge(account: account))
        org.save!
        OrganizationSeeder.new(org).call
        render json: org_summary(org), status: :created
      end

      # GET /organization — configurações da empresa ATUAL (singular)
      def show
        authorize @organization
        render json: org_json(@organization)
      end

      # PATCH /organization — atualiza a empresa ATUAL (singular)
      # PATCH /organizations/:id — edita uma empresa específica (nome / ativa) — msp_admin
      # Empresas NUNCA são deletadas, apenas inativadas (active: false).
      def update
        if params[:id].present?
          org = accessible_organizations.find(params[:id])
          authorize org
          attrs = company_params
          # Inativar/reativar empresa é exclusivo do msp_admin (super admin).
          attrs = attrs.except(:active) unless current_user.msp_admin?
          org.update!(attrs)
          render json: org_summary(org)
        else
          authorize @organization
          @organization.update!(organization_params)
          render json: org_json(@organization)
        end
      end

      private

      def accessible_organizations
        account = current_user.organization.account
        if current_user.msp_admin? && account
          account.organizations
        else
          Organization.where(id: current_user.organization_id)
        end
      end

      def org_summary(org)
        org.as_json(only: %i[id name slug ticket_prefix timezone active master])
      end

      def company_params
        # Edição por-id (msp_admin): nome, ativar/inativar e limite de usuários.
        params.require(:organization).permit(:name, :active, :max_users)
      end

      def org_json(org)
        org.as_json(only: %i[id name slug ticket_prefix timezone date_format emails_enabled email_settings audit_settings max_users master created_at updated_at])
           .merge(
             attachments_enabled: true,
             email_types:         Organization::EMAIL_TYPES,
             audit_types:         Organization::AUDIT_EVENT_TYPES,
             user_count:          org.users.count
           )
      end

      def create_org_params
        params.require(:organization).permit(:name, :slug, :ticket_prefix, :timezone, :date_format)
      end

      def organization_params
        # emails_enabled removido: não existe master de e-mail (controle é por tipo).
        permitted = %i[name timezone date_format]
        # max_users (limite de plano) só pode ser alterado pelo super admin —
        # um admin comum não pode elevar o próprio limite.
        permitted << :max_users if current_user.msp_admin?
        params.require(:organization).permit(
          *permitted,
          email_settings: Organization::EMAIL_TYPES,
          audit_settings: Organization::AUDIT_EVENT_TYPES
        )
      end
    end
  end
end
