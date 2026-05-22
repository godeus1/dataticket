module Api
  module V1
    class EventsController < ApplicationController
      include Pagy::Backend

      def index
        authorize Event
        events = policy_scope(Event).includes(:actor).recent
        events = apply_filters(events)

        @pagy, events = pagy(events, limit: params.fetch(:per_page, 50).to_i)

        render json: {
          events:     EventBlueprint.render_as_hash(events),
          pagination: pagy_metadata(@pagy)
        }
      end

      private

      def apply_filters(scope)
        scope = scope.where(aggregate_type: params[:aggregate_type]) if params[:aggregate_type].present?
        scope = scope.where(aggregate_id:   params[:aggregate_id])   if params[:aggregate_id].present?
        scope = scope.by_type(params[:event_type])                   if params[:event_type].present?
        scope = scope.where("occurred_at >= ?", Date.parse(params[:from])) if params[:from].present?
        scope = scope.where("occurred_at <= ?", Date.parse(params[:to]).end_of_day) if params[:to].present?
        scope
      rescue ArgumentError
        scope
      end
    end
  end
end
