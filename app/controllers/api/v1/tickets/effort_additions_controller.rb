module Api
  module V1
    module Tickets
      class EffortAdditionsController < ApplicationController
        before_action :set_ticket
        before_action :set_addition, only: %i[destroy]

        def index
          authorize @ticket, :show?
          render json: serialize(@ticket.effort_additions.includes(:user).recent)
        end

        def create
          authorize @ticket, :add_effort?

          hours  = params[:hours].to_f
          reason = params[:reason].to_s.strip
          return render json: { error: "Informe as horas de esforço (maior que zero)." }, status: :unprocessable_entity unless hours > 0
          return render json: { error: "Descreva brevemente o que será feito (prova do esforço)." }, status: :unprocessable_entity if reason.blank?

          addition = EffortAdditionService.add(
            ticket: @ticket, user: current_user, hours: hours, reason: reason, source: "manual"
          )
          render json: serialize_one(addition.reload), status: :created
        end

        def destroy
          authorize @ticket, :remove_effort?
          EffortAdditionService.remove(addition: @addition)
          head :no_content
        end

        private

        def set_ticket
          @ticket = policy_scope(Ticket).find(params[:ticket_id])
        end

        def set_addition
          @addition = @ticket.effort_additions.find(params[:id])
        end

        def serialize(scope)
          scope.map { |a| serialize_one(a) }
        end

        def serialize_one(a)
          {
            id:         a.id,
            hours:      a.hours.to_f,
            reason:     a.reason,
            source:     a.source,
            created_at: a.created_at,
            user:       a.user && { id: a.user.id, first_name: a.user.first_name, last_name: a.user.last_name }
          }
        end
      end
    end
  end
end
