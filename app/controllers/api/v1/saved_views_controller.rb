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
        attrs = view_params
        view = scope.create!(name: attrs[:name].to_s, filters: attrs[:filters] || {})
        render json: serialize_one(view), status: :created
      end

      def update
        skip_authorization
        attrs = view_params
        # Fixar: apenas UMA lista fixada por usuário+empresa.
        scope.where.not(id: @view.id).update_all(pinned: false) if attrs[:pinned] == true
        @view.update!(attrs)
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
      # PARCIAL: só inclui as chaves realmente enviadas — atualizar filtros não
      # pode zerar o nome, e renomear não pode apagar os filtros.
      def view_params
        vp  = params.require(:saved_view)
        out = {}
        out[:name] = vp[:name].to_s if vp.key?(:name)
        if vp.key?(:filters)
          raw = vp[:filters]
          out[:filters] = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : (raw || {})
        end
        out[:pinned] = ActiveModel::Type::Boolean.new.cast(vp[:pinned]) if vp.key?(:pinned)
        out
      end

      def serialize(views)
        views.map { |v| serialize_one(v) }
      end

      def serialize_one(v)
        { id: v.id, name: v.name, filters: v.filters, pinned: v.pinned }
      end
    end
  end
end
