module Api
  module V1
    class TriageRulesController < ApplicationController
      before_action :set_rule, only: %i[show update destroy]

      def index
        authorize TriageRule
        rules = policy_scope(TriageRule).includes(:category, :priority, :queue).ordered
        render json: TriageRuleBlueprint.render_as_hash(rules)
      end

      def show
        authorize @rule
        render json: TriageRuleBlueprint.render_as_hash(@rule)
      end

      def create
        authorize TriageRule
        rule = @organization.triage_rules.create!(rule_params)
        render json: TriageRuleBlueprint.render_as_hash(rule), status: :created
      end

      def update
        authorize @rule
        @rule.update!(rule_params)
        render json: TriageRuleBlueprint.render_as_hash(@rule)
      end

      def destroy
        authorize @rule
        @rule.destroy!
        head :no_content
      end

      private

      def set_rule
        @rule = policy_scope(TriageRule).find(params[:id])
      end

      def rule_params
        params.require(:triage_rule).permit(
          :name, :keyword, :category_id, :priority_id, :queue_id, :position, :active
        )
      end
    end
  end
end
