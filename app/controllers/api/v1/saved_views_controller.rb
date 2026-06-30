module Api
  module V1
    # Listas salvas de filtros da tela de tickets — por usuário e por empresa.
    class SavedViewsController < ApplicationController
      before_action :set_view, only: %i[update destroy]

      def index
        skip_authorization
        render json: serialize(scope.recent)
      end

      def create
        skip_authorization
        view = scope.create!(name: view_params[:name], filters: view_params[:filters])
        render json: serialize_one(view), status: :created
      end

      def update
        skip_authorization
        @view.update!(view_params)
        render json: serialize_one(@view)
      end

      def destroy
        skip_authorization
        @view.destroy!
        head :no_content
      end

      private

      # Sempre escopado ao usuário atual + empresa efetiva (Current.organization).
      def scope
        current_user.saved_views.where(organization: @organization)
      end

      def set_view
        @view = scope.find(params[:id])
      end

      # filters é um jsonb arbitrário (config de filtros do usuário — não sensível).
      def view_params
        vp = params.require(:saved_view)
        raw = vp[:filters]
        {
          name:    vp[:name].to_s,
          filters: (raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : (raw || {}))
        }
      end

      def serialize(views)
        views.map { |v| serialize_one(v) }
      end

      def serialize_one(v)
        { id: v.id, name: v.name, filters: v.filters }
      end
    end
  end
end
