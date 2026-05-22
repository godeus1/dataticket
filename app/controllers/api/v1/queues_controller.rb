module Api
  module V1
    class QueuesController < ApplicationController
      before_action :set_queue, only: %i[show update destroy add_member remove_member]

      def index
        authorize TicketQueue
        queues = @organization.queues.includes(:members)
        render json: queues.as_json(
          only: %i[id name description active],
          include: { members: { only: %i[id first_name last_name email role] } }
        )
      end

      def show
        authorize @queue
        render json: @queue.as_json(
          only: %i[id name description active created_at updated_at],
          include: { members: { only: %i[id first_name last_name email role] } }
        )
      end

      def create
        authorize TicketQueue
        queue = @organization.queues.new(queue_params)
        queue.save!
        render json: queue.as_json(only: %i[id name description active]), status: :created
      end

      def update
        authorize @queue
        @queue.update!(queue_params)
        render json: @queue.as_json(only: %i[id name description active])
      end

      def destroy
        authorize @queue
        @queue.destroy!
        head :no_content
      end

      def add_member
        authorize @queue, :update?
        user = @organization.users.find(params[:user_id])
        @queue.members << user unless @queue.members.include?(user)
        render json: { message: "Membro adicionado com sucesso" }
      end

      def remove_member
        authorize @queue, :update?
        user = @organization.users.find(params[:user_id])
        @queue.members.delete(user)
        head :no_content
      end

      private

      def set_queue
        @queue = @organization.queues.find(params[:id])
      end

      def queue_params
        params.require(:queue).permit(:name, :description, :active, :category_id)
      end
    end
  end
end
