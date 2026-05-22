module Api
  module V1
    module Tickets
      class AttachmentsController < ApplicationController
        before_action :set_ticket
        before_action :set_attachment, only: %i[destroy]

        def index
          authorize TicketAttachment
          attachments = @ticket.ticket_attachments.includes(:user).order(created_at: :asc)
          render json: attachments.as_json(
            only: %i[id filename content_type byte_size created_at],
            include: { user: { only: %i[id first_name last_name] } }
          )
        end

        def create
          authorize TicketAttachment
          attachment = @ticket.ticket_attachments.new(
            filename:     params[:file]&.original_filename || params[:filename],
            content_type: params[:file]&.content_type || params[:content_type],
            byte_size:    params[:file]&.size || 0,
            user:         current_user
          )
          attachment.save!
          render json: attachment.as_json(only: %i[id filename content_type byte_size created_at]),
                 status: :created
        end

        def destroy
          authorize @attachment
          @attachment.destroy!
          head :no_content
        end

        private

        def set_ticket
          @ticket = policy_scope(Ticket).find(params[:ticket_id])
        end

        def set_attachment
          @attachment = @ticket.ticket_attachments.find(params[:id])
        end
      end
    end
  end
end
