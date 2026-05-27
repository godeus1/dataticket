module Api
  module V1
    module Tickets
      class TimerSessionsController < ApplicationController
        before_action :set_ticket
        before_action :set_timer_session, only: %i[stop]

        # GET /api/v1/tickets/:ticket_id/timer_sessions
        def index
          authorize TicketTimerSession
          sessions = @ticket.timer_sessions.includes(:user).chronological
          render json: serialize(sessions)
        end

        # POST /api/v1/tickets/:ticket_id/timer_sessions
        # Legacy endpoint — accepts a fully-formed (completed) session from the frontend.
        def create
          authorize TicketTimerSession
          session_attrs = timer_session_params.merge(user: current_user, status: "completed")
          session = @ticket.timer_sessions.new(session_attrs)
          session.save!
          render json: serialize_one(session), status: :created
        end

        # POST /api/v1/tickets/:ticket_id/timer_sessions/start
        # Starts a new running session for the current user on this ticket.
        # Cancels any other running session this user has across the entire organization.
        def start
          authorize TicketTimerSession, :start?

          # ── Bloqueia timer em tickets fechados ou resolvidos ───────────────
          if %w[Fechado Resolvido].include?(@ticket.status)
            return render json: { error: "Não é possível iniciar o cronômetro em um ticket #{@ticket.status.downcase}." },
                          status: :unprocessable_entity
          end

          # ── Cancel ALL running sessions for this user across the whole org ──
          # This enforces the "one active timer per user" rule globally.
          # update_all + insert_all em lote: 2 queries totais em vez de N×2.
          running_sessions = TicketTimerSession
            .joins(:ticket)
            .where(tickets: { organization_id: @ticket.organization_id, deleted_at: nil })
            .where(user: current_user, status: "running")
            .select("ticket_timer_sessions.id, ticket_timer_sessions.ticket_id")
            .to_a

          if running_sessions.any?
            now = Time.current
            TicketTimerSession.where(id: running_sessions.map(&:id))
                              .update_all(stopped_at: now, duration_mins: 0.0, status: "cancelled")
            TicketHistory.insert_all(
              running_sessions.map do |s|
                {
                  ticket_id:  s.ticket_id,
                  user_id:    current_user.id,
                  field:      "cronômetro",
                  from_value: "Em andamento",
                  to_value:   "Cancelado (novo timer iniciado em outro ticket)",
                  created_at: now,
                  updated_at: now
                }
              end
            )
          end

          session = @ticket.timer_sessions.create!(
            user:       current_user,
            started_at: Time.current,
            status:     "running"
          )

          # ── Change ticket status to "Em andamento" if appropriate ──────────
          startable_statuses = [
            "Triado, aguardando atendimento",
            "Não iniciado",
            "Reaberto",
            "Aguardando terceiros",
            "Aguardando solicitante"
          ]
          if startable_statuses.include?(@ticket.status)
            TicketStatusService.new(@ticket, "Em andamento", current_user).call
            @ticket.reload
          end

          # Record timer start in ticket history
          @ticket.histories.create!(
            user:       current_user,
            field:      "cronômetro",
            from_value: nil,
            to_value:   "Iniciado por #{current_user.full_name}"
          ) rescue nil

          render json: { session: serialize_one(session), ticket_status: @ticket.status }, status: :created
        end

        # PATCH /api/v1/tickets/:ticket_id/timer_sessions/:id/stop
        # Stops a running session, computes duration_mins, triggers schedule reallocation.
        def stop
          authorize @timer_session, :stop?

          unless @timer_session.running?
            return render json: { error: "Sessão não está em andamento" }, status: :unprocessable_entity
          end

          @timer_session.stop!

          # Update effort_used on the ticket
          added_hours = @timer_session.duration_mins / 60.0
          new_effort  = (@ticket.effort_used.to_f + added_hours).round(2)
          @ticket.update_columns(effort_used: new_effort)

          # Record timer stop in ticket history
          duration_label = format_duration(@timer_session.duration_mins)
          @ticket.histories.create!(
            user:       current_user,
            field:      "cronômetro",
            from_value: "Em andamento",
            to_value:   "#{duration_label} registrado por #{current_user.full_name}"
          ) rescue nil

          # ── Revert status to "Triado, aguardando atendimento" if effort not exhausted ──
          # Only when ticket was "Em andamento" and effort is not fully used.
          effort_est = @ticket.effort_estimated.to_f
          effort_exhausted = effort_est > 0 && new_effort >= effort_est

          if @ticket.status == "Em andamento" && !effort_exhausted
            TicketStatusService.new(@ticket.reload, "Triado, aguardando atendimento", current_user).call
            @ticket.reload
          end

          # Reagenda em background — libera a response imediatamente
          TicketRescheduleJob.perform_later(@ticket.id, nil) if @ticket.assignee_id.present?

          render json: { session: serialize_one(@timer_session), ticket_status: @ticket.status, effort_used: new_effort }
        end

        private

        def set_ticket
          @ticket = policy_scope(Ticket).find(params[:ticket_id])
        end

        def set_timer_session
          @timer_session = @ticket.timer_sessions.find(params[:id])
        end

        def timer_session_params
          params.permit(:started_at, :stopped_at, :duration_mins)
        end

        def serialize(sessions)
          sessions.map { |s| serialize_one(s) }
        end

        def serialize_one(s)
          {
            id:            s.id,
            started_at:    s.started_at,
            stopped_at:    s.stopped_at,
            duration_mins: s.duration_mins,
            status:        s.status,
            user_id:       s.user_id,
            user_name:     s.user&.full_name,
          }
        end

        def format_duration(mins)
          total = mins.to_i
          h = total / 60
          m = total % 60
          h > 0 ? "#{h}h#{m > 0 ? " #{m}min" : ""}" : "#{m}min"
        end
      end
    end
  end
end
