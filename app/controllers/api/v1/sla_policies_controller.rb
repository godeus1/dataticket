module Api
  module V1
    class SlaPoliciesController < ApplicationController
      before_action :set_policy, only: %i[show update destroy]

      def index
        authorize SlaPolicy
        policies = policy_scope(SlaPolicy).includes(:priority, :category).active
        render json: SlaPolicyBlueprint.render_as_hash(policies)
      end

      def show
        authorize @sla_policy
        render json: SlaPolicyBlueprint.render_as_hash(@sla_policy)
      end

      def create
        authorize SlaPolicy
        sla = @organization.sla_policies.create!(sla_params)
        render json: SlaPolicyBlueprint.render_as_hash(sla), status: :created
      end

      def update
        authorize @sla_policy
        @sla_policy.update!(sla_params)
        render json: SlaPolicyBlueprint.render_as_hash(@sla_policy)
      end

      def destroy
        authorize @sla_policy
        @sla_policy.destroy!
        head :no_content
      end

      private

      def set_policy
        @sla_policy = policy_scope(SlaPolicy).find(params[:id])
      end

      def sla_params
        params.require(:sla_policy).permit(
          :priority_id, :category_id, :response_hours, :resolve_hours, :active
        )
      end
    end
  end
end
