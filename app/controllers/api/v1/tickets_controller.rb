module Api
  module V1
    class TicketsController < ApplicationController
      include Pagy::Backend

      before_action :set_ticket, only: %i[show update destroy triage change_status assign histories restore purge]

      def index
        authorize Ticket
        tickets = policy_scope(Ticket).includes(:requester, :assignee, :category, :priority, :queue, :tags, :co_assignees)
        tickets = apply_filters(tickets)
        tickets = apply_search(tickets)
        tickets = tickets.order(created_at: :desc)

        @pagy, tickets = pagy(tickets, limit: params.fetch(:per_page, 500).to_i)

        render json: {
          tickets:    TicketBlueprint.render_as_hash(tickets, view: :summary),
          pagination: pagy_metadata(@pagy)
        }
      end

      def trash
        authorize Ticket, :trash_index?
        tickets = @organization.tickets.trashed
                               .includes(:requester, :assignee, :category, :priority)
                               .order(deleted_at: :desc)
        render json: TicketBlueprint.render_as_hash(tickets, view: :trash)
      end

      def show
        authorize @ticket
        render json: TicketBlueprint.render_as_hash(@ticket, view: :full)
      end

      def create
        authorize Ticket
        ticket = @organization.tickets.new(ticket_params.merge(requester: current_user))
        ticket.save!
        apply_tags(ticket)
        apply_co_assignees(ticket)
        apply_custom_field_values(ticket)
        audit!(
          action:    "Ticket criado",
          entity:    "Ticket",
          entity_id: ticket.id,
          changes:   { titulo: ticket.title, categoria: ticket.category&.name, solicitante: current_user.full_name }
        )
        TicketMailer.created(ticket).deliver_later if ticket.organization.emails_enabled?
        render json: TicketBlueprint.render_as_hash(ticket, view: :full), status: :created
      end

      def update
        authorize @ticket
        @ticket.update!(ticket_params)
        # Somente admin pode ajustar manualmente a data de abertura.
        # Usamos update_column para ignorar validações e callbacks (apenas timestamp).
        if current_user.admin? && params.dig(:ticket, :created_at).present?
          @ticket.update_column(:created_at, params[:ticket][:created_at])
        end
        apply_tags(@ticket)
        apply_co_assignees(@ticket)
        apply_custom_field_values(@ticket)
        render json: TicketBlueprint.render_as_hash(@ticket, view: :full)
      end

      # Soft delete — move para lixeira (admin only)
      def destroy
        authorize @ticket
        saved_title = @ticket.title
        @ticket.soft_delete!(current_user)
        audit!(
          action:    "Ticket excluído (lixeira)",
          entity:    "Ticket",
          entity_id: @ticket.id,
          changes:   { titulo: saved_title }
        )
        head :no_content
      end

      # Restaura da lixeira (admin only)
      def restore
        authorize @ticket, :restore?
        @ticket.restore!(current_user)
        audit!(
          action:    "Ticket restaurado",
          entity:    "Ticket",
          entity_id: @ticket.id,
          changes:   { titulo: @ticket.title }
        )
        render json: TicketBlueprint.render_as_hash(@ticket, view: :full)
      end

      # Exclusão permanente (admin only)
      def purge
        authorize @ticket, :purge?
        saved_title = @ticket.title
        saved_id    = @ticket.id
        audit!(
          action:    "Ticket excluído permanentemente",
          entity:    "Ticket",
          entity_id: saved_id,
          changes:   { titulo: saved_title }
        )
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
        authorize Ticket, :bulk_triage?
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
        # restore e purge precisam encontrar tickets na lixeira também
        scope = %w[restore purge].include?(action_name) ? @organization.tickets : policy_scope(Ticket)
        includes_list = [:requester, :assignee, :category, :priority, :queue,
                         :co_assignees, :comments, :ticket_attachments, :histories,
                         :tags, { field_values: :custom_field }]
        # timer_sessions só existe após a migration — inclui apenas se a tabela existir
        includes_list << :timer_sessions if ActiveRecord::Base.connection.table_exists?(:ticket_timer_sessions)
        @ticket = scope.includes(*includes_list).find(params[:id])
      end

      def ticket_params
        if current_user.analyst?
          params.require(:ticket).permit(:effort_used, :effort_estimated)
        else
          params.require(:ticket).permit(
            :title, :description, :status, :ticket_type,
            :priority_id, :category_id, :queue_id, :assignee_id, :deadline,
            :effort_used, :effort_estimated
          )
        end
      end

      def apply_co_assignees(ticket)
        return unless params[:ticket]&.key?(:co_assignee_ids)
        ticket.sync_co_assignees(params[:ticket][:co_assignee_ids])
      end

      def bulk_triage_params
        params.permit(:priority_id, :category_id, :queue_id, :assignee_id)
      end

      # Replaces all tags on the ticket when tag_ids is present in params
      def apply_tags(ticket)
        return unless params[:ticket]&.key?(:tag_ids)

        tag_ids = Array(params[:ticket][:tag_ids]).map(&:to_i)
        # Scope to org's tags to prevent cross-tenant assignment
        valid_ids = @organization.tags.where(id: tag_ids).pluck(:id)
        ticket.tag_ids = valid_ids
      end

      # Upserts custom field values when custom_field_values is present in params
      def apply_custom_field_values(ticket)
        values = params[:ticket]&.dig(:custom_field_values)
        return unless values.present?

        CustomFieldValueService.new(ticket, values).save!
      rescue CustomFieldValueService::ValidationError => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity and return
      rescue ArgumentError => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity and return
      end

      def apply_filters(scope)
        scope = scope.where(status: params[:status])           if params[:status].present?
        scope = scope.where(priority_id: params[:priority_id]) if params[:priority_id].present?
        scope = scope.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
        scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
        scope = scope.where(queue_id: params[:queue_id])       if params[:queue_id].present?
        scope = scope.overdue                                  if params[:overdue] == "true"
        # Filter by tag: returns tickets that have ALL specified tags
        if params[:tag_ids].present?
          Array(params[:tag_ids]).each do |tag_id|
            scope = scope.joins(:ticket_tags).where(ticket_tags: { tag_id: tag_id })
          end
        end
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
