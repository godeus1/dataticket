module Api
  module V1
    module Tickets
      class CommentsController < ApplicationController
        before_action :set_ticket
        before_action :set_comment, only: %i[destroy]

        def index
          authorize TicketComment
          comments = @ticket.comments.includes(:user).order(created_at: :asc)
          # Comentários internos visíveis apenas para equipe operacional
          comments = comments.public_only unless current_user.role.in?(%w[admin manager analyst])
          render json: comments.as_json(
            only: %i[id body kind created_at updated_at author_name author_email source],
            include: { user: { only: %i[id first_name last_name email avatar_initials avatar_color] } }
          )
        end

        def create
          authorize TicketComment
          # Usuários comuns e analistas sem acesso staff não podem criar comentários internos
          safe_params = comment_params
          if current_user.role.in?(%w[user]) || !current_user.role.in?(%w[admin manager analyst])
            safe_params = safe_params.merge(kind: "public")
          end
          comment = @ticket.comments.new(safe_params.merge(user: current_user))
          comment.save!
          NotificationService.new(@ticket).notify_new_comment(current_user)
          send_comment_emails(comment) if @ticket.organization.email_type_enabled?("new_comment") && comment.kind != "internal"
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

        def send_comment_emails(comment)
          recipients = []
          # Requester recebe se quem comentou não é o próprio requester
          recipients << @ticket.requester if @ticket.requester && @ticket.requester != current_user
          # Assignee recebe se quem comentou não é o próprio assignee
          recipients << @ticket.assignee  if @ticket.assignee  && @ticket.assignee  != current_user
          recipients.uniq.each do |user|
            TicketMailer.new_comment(@ticket, comment, user).deliver_later
          rescue => e
            Rails.logger.error("[comment_email] falha ao notificar #{user.email}: #{e.message}")
          end
        end

        def set_ticket
          @ticket = policy_scope(Ticket).find(params[:ticket_id])
        end

        def set_comment
          @comment = @ticket.comments.find(params[:id])
        end

        def comment_params
          params.require(:ticket_comment).permit(:body, :kind)
        end
      end
    end
  end
end
