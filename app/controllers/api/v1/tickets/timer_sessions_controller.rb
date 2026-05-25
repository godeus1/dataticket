module Api
  module V1
    module Tickets
      class TimerSessionsController < ApplicationController
        before_action :set_ticket

        # GET /api/v1/tickets/:ticket_id/timer_sessions
        def index
          authorize TicketTimerSession
          sessions = @ticket.timer_sessions.includes(:user).chronological
          render json: serialize(sessions)
        end

        # POST /api/v1/tickets/:ticket_id/timer_sessions
        def create
          authorize TicketTimerSession
          session = @ticket.timer_sessions.new(timer_session_params.merge(user: current_user))
          session.save!
          render json: serialize([session]).first, status: :created
        end

        private

        def set_ticket
          @ticket = policy_scope(Ticket).find(params[:ticket_id])
        end

        def timer_session_params
          params.permit(:started_at, :stopped_at, :duration_mins)
        end

        def serialize(sessions)
          sessions.map do |s|
            {
              id:            s.id,
              started_at:    s.started_at,
              stopped_at:    s.stopped_at,
              duration_mins: s.duration_mins,
              user_id:       s.user_id,
              user_name:     s.user&.full_name,
            }
          end
        end
      end
    end
  end
end
