module Api
  module V1
    class TicketsController < ApplicationController
      include Pagy::Backend

      before_action :set_ticket, only: %i[show update destroy triage change_status assign histories restore purge]

      def index
        authorize Ticket
        tickets = policy_scope(Ticket).includes(:requester, :assignee, :category, :priority, :queue, :tags, :co_assignees, :scheduled_days)
        tickets = apply_filters(tickets)
        tickets = apply_search(tickets)
        # Secondary sort by id ensures stable cursor position when created_at ties.
        tickets = tickets.order(created_at: :desc, id: :desc)

        if params[:cursor].present?
          render json: cursor_paginate(tickets)
        else
          per_page = [[params.fetch(:per_page, 50).to_i, 1].max, 500].min
          @pagy, tickets = pagy(tickets, limit: per_page)
          render json: {
            tickets:    TicketBlueprint.render_as_hash(tickets, view: :summary),
            pagination: pagy_metadata(@pagy)
          }
        end
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

        # Captura valores antes da atualização para detectar mudanças que afetam agenda
        old_assignee_id  = @ticket.assignee_id
        old_effort       = @ticket.effort_estimated.to_f
        old_priority_id  = @ticket.priority_id

        @ticket.update!(ticket_params)

        # Somente admin pode ajustar manualmente a data de abertura.
        if current_user.admin? && params.dig(:ticket, :created_at).present?
          @ticket.update_column(:created_at, params[:ticket][:created_at])
        end

        apply_tags(@ticket)
        apply_co_assignees(@ticket)
        apply_custom_field_values(@ticket)

        # Reagenda agenda quando campos que impactam o calendário mudam
        reschedule_after_update(old_assignee_id, old_effort, old_priority_id)

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
        # Analistas só podem fechar (policy permite se esforço esgotado; aqui reforçamos o status)
        if current_user.analyst? && params[:status] != "Fechado"
          return render json: { errors: [ "Analistas só podem fechar tickets." ] }, status: :forbidden
        end
        additional_hours = params[:additional_hours].present? ? params[:additional_hours].to_f : nil
        result = TicketStatusService.new(@ticket, params[:status], current_user, additional_hours: additional_hours).call
        if result.success?
          render json: TicketBlueprint.render_as_hash(result.ticket, view: :full)
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      def assign
        authorize @ticket, :assign?
        old_assignee_id = @ticket.assignee_id
        assignee        = @organization.users.find(params[:assignee_id])
        @ticket.update!(assignee: assignee)

        # Libera capacidade do responsável anterior
        if old_assignee_id.present? && old_assignee_id.to_s != assignee.id.to_s
          old_assignee = @organization.users.find_by(id: old_assignee_id)
          if old_assignee
            @ticket.scheduled_days.where(user: old_assignee).where("date >= ?", Date.current).destroy_all
            ScheduleReallocationService.new(old_assignee, @organization).call
          end
        end

        # Recalcula prazo + agenda do novo responsável via TicketDeadlineCalculator
        calc = TicketDeadlineCalculator.new(@ticket).call
        if calc.deadline
          @ticket.update_columns(deadline: calc.deadline)
          ScheduleService.new(@ticket, calc.days).schedule
        end

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
        # Analysts creating their own tickets need title/description/category.
        # The effort-only restriction applies only when updating an existing ticket.
        if current_user.analyst? && action_name != "create"
          params.require(:ticket).permit(:effort_used, :effort_estimated)
        else
          params.require(:ticket).permit(
            :title, :description, :status, :ticket_type,
            :priority_id, :category_id, :queue_id, :assignee_id, :requester_id, :deadline,
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

      # Dispara reagendamento quando campos que afetam a agenda mudam no update.
      #
      # Casos tratados:
      #   assignee mudou   → realoca agenda do antigo E do novo responsável
      #   effort_estimated → realoca agenda do responsável atual
      #   priority_id      → reordena prioridades na agenda do responsável atual
      #
      # Detecta mudanças que afetam a agenda e delega o recálculo pesado para
      # TicketRescheduleJob (background). Apenas o cleanup imediato dos
      # scheduled_days do antigo responsável ocorre de forma síncrona para evitar
      # double-booking enquanto o job ainda não rodou.
      def reschedule_after_update(old_assignee_id, old_effort, old_priority_id)
        new_assignee_id  = @ticket.assignee_id
        assignee_changed = new_assignee_id.to_s != old_assignee_id.to_s
        effort_changed   = @ticket.effort_estimated.to_f != old_effort
        priority_changed = @ticket.priority_id.to_s != old_priority_id.to_s

        return unless assignee_changed || effort_changed || priority_changed

        # Libera a capacidade do antigo responsável de forma síncrona — sem isso
        # os scheduled_days ficariam alocados até o job rodar, causando overbooking.
        if assignee_changed && old_assignee_id.present?
          old_assignee = @organization.users.find_by(id: old_assignee_id)
          if old_assignee
            @ticket.scheduled_days
                   .where(user: old_assignee)
                   .where("date >= ?", Date.current)
                   .destroy_all
          end
        end

        # O recálculo pesado de ScheduleReallocationService vai para background.
        # old_assignee_id é passado para o job poder realocar o antigo responsável.
        TicketRescheduleJob.perform_later(@ticket.id, old_assignee_id&.to_s)
      rescue StandardError => e
        Rails.logger.error("[reschedule_after_update] ticket #{@ticket.id}: #{e.message}")
      end

      # Cursor-based pagination (keyset).
      # Cursor encodes {ts: ISO8601, id_num: integer} of the last item in the previous page.
      # Compound condition (created_at, numeric_id) avoids gaps or duplicates when tickets
      # share the same created_at timestamp.
      # id_num (numeric suffix of TK-NNNN) is used instead of the raw id string so
      # ordering is correct even for IDs with more than 4 digits (TK-10000+).
      def cursor_paginate(scope)
        per_page = [[params.fetch(:per_page, 50).to_i, 1].max, 200].min

        if params[:cursor].present?
          decoded  = JSON.parse(Base64.strict_decode64(params[:cursor]))
          ts       = decoded["ts"]
          id_num   = decoded["id_num"].to_i
          scope = scope.where(
            "(created_at < ?) OR (created_at = ? AND CAST(SUBSTRING(id, 4) AS INTEGER) < ?)",
            ts, ts, id_num
          )
        end

        records  = scope.limit(per_page + 1).to_a
        has_more = records.size > per_page
        records  = records.first(per_page)

        next_cursor = if has_more && records.any?
          last = records.last
          Base64.strict_encode64(
            JSON.generate({ ts: last.created_at.iso8601(6), id_num: last.id.sub(/^TK-/, "").to_i })
          )
        end

        {
          tickets:     TicketBlueprint.render_as_hash(records, view: :summary),
          next_cursor: next_cursor,
          has_more:    has_more
        }
      rescue ArgumentError, JSON::ParserError
        render json: { error: "Cursor inválido" }, status: :bad_request and return
      end

      def apply_filters(scope)
        scope = scope.where(status: params[:status])           if params[:status].present?
        scope = scope.where(priority_id: params[:priority_id]) if params[:priority_id].present?
        scope = scope.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
        scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
        scope = scope.where(queue_id: params[:queue_id])       if params[:queue_id].present?
        scope = scope.overdue                                  if params[:overdue] == "true"
        # Filter by tag: returns tickets that have ALL specified tags.
        # Single JOIN + GROUP/HAVING replaces the old loop of N joins (one per tag),
        # which produced cartesian complexity. Semantics are identical.
        if params[:tag_ids].present?
          ids = Array(params[:tag_ids]).map(&:to_i).uniq
          scope = scope.joins(:ticket_tags)
                       .where(ticket_tags: { tag_id: ids })
                       .group("tickets.id")
                       .having("COUNT(DISTINCT ticket_tags.tag_id) = ?", ids.size)
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
