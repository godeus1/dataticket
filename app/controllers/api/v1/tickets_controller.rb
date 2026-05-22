module Api
  module V1
    class TicketsController < ApplicationController
      include Pagy::Backend

      before_action :set_ticket, only: %i[show update destroy triage change_status assign histories]

      def index
        authorize Ticket
        tickets = policy_scope(Ticket).includes(:requester, :assignee, :category, :priority, :queue)
        tickets = apply_filters(tickets)
        tickets = apply_search(tickets)
        tickets = tickets.order(created_at: :desc)

        @pagy, tickets = pagy(tickets, limit: params.fetch(:per_page, 25).to_i)

        render json: {
          tickets:    TicketBlueprint.render_as_hash(tickets, view: :summary),
          pagination: pagy_metadata(@pagy)
        }
      end

      def show
        authorize @ticket
        render json: TicketBlueprint.render_as_hash(@ticket, view: :full)
      end

      def create
        authorize Ticket
        ticket = @organization.tickets.new(ticket_params.merge(requester: current_user))
        ticket.save!
        TicketMailer.created(ticket).deliver_later if ticket.organization.emails_enabled?
        render json: TicketBlueprint.render_as_hash(ticket, view: :full), status: :created
      end

      def update
        authorize @ticket
        @ticket.update!(ticket_params)
        render json: TicketBlueprint.render_as_hash(@ticket, view: :full)
      end

      def destroy
        authorize @ticket
        @ticket.destroy!
        head :no_content
      end

      def triage
        authorize @ticket, :triage?
        result = TriageService.new(@ticket, params, current_user).call
        if result.success?
          render json: TicketBlueprint.render_as_hash(result.ticket, view: :full)
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      def change_status
        authorize @ticket, :change_status?
        result = TicketStatusService.new(@ticket, params[:status], current_user).call
        if result.success?
          render json: TicketBlueprint.render_as_hash(result.ticket, view: :full)
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      def assign
        authorize @ticket, :assign?
        assignee = @organization.users.find(params[:assignee_id])
        @ticket.update!(assignee: assignee)
        NotificationService.new(@ticket).notify_assignee(assignee)
        TicketMailer.assigned(@ticket).deliver_later if @ticket.organization.emails_enabled?
        render json: TicketBlueprint.render_as_hash(@ticket, view: :full)
      end

      def histories
        authorize @ticket, :show?
        histories = @ticket.histories.includes(:user).recent
        render json: histories.as_json(
          only: %i[id field from_value to_value created_at],
          include: { user: { only: %i[id first_name last_name email] } }
        )
      end

      def bulk_triage
        authorize Ticket, :triage?
        result = BulkTriageService.new(
          params[:ticket_ids],
          bulk_triage_params,
          current_user
        ).call

        render json: {
          success:  result.success?,
          triaged:  result.triaged,
          skipped:  result.skipped,
          errors:   result.errors
        }, status: result.success? ? :ok : :unprocessable_entity
      end

      private

      def set_ticket
        @ticket = policy_scope(Ticket)
                    .includes(:requester, :assignee, :category, :priority, :queue,
                              :comments, :ticket_attachments, :histories)
                    .find(params[:id])
      end

      def ticket_params
        params.require(:ticket).permit(
          :title, :description, :status, :ticket_type,
          :priority_id, :category_id, :queue_id, :assignee_id, :deadline
        )
      end

      def bulk_triage_params
        params.permit(:priority_id, :category_id, :queue_id, :assignee_id)
      end

      def apply_filters(scope)
        scope = scope.where(status: params[:status])        if params[:status].present?
        scope = scope.where(priority_id: params[:priority_id]) if params[:priority_id].present?
        scope = scope.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
        scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
        scope = scope.where(queue_id: params[:queue_id])       if params[:queue_id].present?
        scope = scope.overdue                                  if params[:overdue] == "true"
        scope
      end

      def apply_search(scope)
        return scope unless params[:q].present?

        term = "%#{params[:q]}%"
        scope.where("tickets.title ILIKE :q OR tickets.description ILIKE :q", q: term)
      end
    end
  end
end
