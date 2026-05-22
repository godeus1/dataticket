module Api
  module V1
    class QueuesController < ApplicationController
      before_action :set_queue, only: %i[show update destroy add_member remove_member]

      def index
        authorize TicketQueue
        queues = @organization.queues.includes(:users, :category)
        render json: QueueBlueprint.render_as_hash(queues)
      end

      def show
        authorize @queue
        render json: QueueBlueprint.render_as_hash(@queue)
      end

      def create
        authorize TicketQueue
        queue = @organization.queues.new(queue_params)
        queue.save!
        render json: QueueBlueprint.render_as_hash(queue), status: :created
      end

      def update
        authorize @queue
        @queue.update!(queue_params)
        render json: QueueBlueprint.render_as_hash(@queue)
      end

      def destroy
        authorize @queue
        @queue.destroy!
        head :no_content
      end

      def add_member
        authorize @queue, :update?
        user = @organization.users.find(params[:user_id])
        @queue.users << user unless @queue.users.include?(user)
        render json: { message: "Membro adicionado com sucesso" }
      end

      def remove_member
        authorize @queue, :update?
        user = @organization.users.find(params[:user_id])
        @queue.users.delete(user)
        head :no_content
      end

      private

      def set_queue
        @queue = @organization.queues.includes(:users, :category).find(params[:id])
      end

      def queue_params
        params.require(:queue).permit(:name, :description, :active, :category_id)
      end
    end
  end
end
