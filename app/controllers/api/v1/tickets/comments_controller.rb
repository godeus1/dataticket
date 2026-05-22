module Api
  module V1
    module Tickets
      class CommentsController < ApplicationController
        before_action :set_ticket
        before_action :set_comment, only: %i[destroy]

        def index
          authorize TicketComment
          comments = @ticket.ticket_comments.includes(:user).order(created_at: :asc)
          comments = comments.public_only unless current_user.role.in?(%w[admin analyst])
          render json: comments.as_json(
            only: %i[id body kind created_at updated_at],
            include: { user: { only: %i[id first_name last_name email avatar_initials avatar_color] } }
          )
        end

        def create
          authorize TicketComment
          comment = @ticket.ticket_comments.new(comment_params.merge(user: current_user))
          comment.save!
          render json: comment.as_json(
            only: %i[id body kind created_at],
            include: { user: { only: %i[id first_name last_name email avatar_initials avatar_color] } }
          ), status: :created
        end

        def destroy
          authorize @comment
          @comment.destroy!
          head :no_content
        end

        private

        def set_ticket
          @ticket = policy_scope(Ticket).find(params[:ticket_id])
        end

        def set_comment
          @comment = @ticket.ticket_comments.find(params[:id])
        end

        def comment_params
          params.require(:ticket_comment).permit(:body, :kind)
        end
      end
    end
  end
end
