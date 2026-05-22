module Api
  module V1
    class PrioritiesController < ApplicationController
      before_action :set_priority, only: %i[show update destroy]

      def index
        authorize Priority
        priorities = @organization.priorities.ordered
        render json: priorities.as_json(only: %i[id name color sla_hours sla_days active position])
      end

      def show
        authorize @priority
        render json: @priority.as_json(only: %i[id name color sla_hours sla_days active position created_at updated_at])
      end

      def create
        authorize Priority
        priority = @organization.priorities.new(priority_params)
        priority.save!
        render json: priority.as_json(only: %i[id name color sla_hours sla_days active position]), status: :created
      end

      def update
        authorize @priority
        @priority.update!(priority_params)
        render json: @priority.as_json(only: %i[id name color sla_hours sla_days active position])
      end

      def destroy
        authorize @priority
        @priority.destroy!
        head :no_content
      end

      private

      def set_priority
        @priority = @organization.priorities.find(params[:id])
      end

      def priority_params
        params.require(:priority).permit(:name, :color, :sla_hours, :sla_days, :active, :position)
      end
    end
  end
end
