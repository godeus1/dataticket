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
        seed_defaults(org)
        render json: org_summary(org), status: :created
      end

      # GET /organization — configurações da empresa ATUAL (singular)
      def show
        authorize @organization
        render json: org_json(@organization)
      end

      # PATCH /organization — atualiza a empresa atual
      def update
        authorize @organization
        @organization.update!(organization_params)
        render json: org_json(@organization)
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

      # Seed mínimo para uma empresa nova ser utilizável de imediato.
      def seed_defaults(org)
        [
          { name: "Baixa",   sla_hours: 72, sla_days: 5, position: 1, color: "#6b7280" },
          { name: "Média",   sla_hours: 48, sla_days: 3, position: 2, color: "#2383e2" },
          { name: "Alta",    sla_hours: 24, sla_days: 1, position: 3, color: "#d97706" },
          { name: "Crítica", sla_hours: 4,  sla_days: 1, position: 4, color: "#dc2626" },
        ].each { |attrs| org.priorities.create!(attrs) }
        org.categories.create!(name: "Geral", color: "#2383e2", active: true)
      end

      def org_summary(org)
        org.as_json(only: %i[id name slug ticket_prefix timezone])
      end

      def org_json(org)
        org.as_json(only: %i[id name slug ticket_prefix timezone date_format emails_enabled created_at updated_at])
           .merge(attachments_enabled: true)
      end

      def create_org_params
        params.require(:organization).permit(:name, :slug, :ticket_prefix, :timezone, :date_format)
      end

      def organization_params
        params.require(:organization).permit(:name, :timezone, :date_format, :emails_enabled)
      end
    end
  end
end
