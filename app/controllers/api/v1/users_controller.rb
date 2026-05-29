module Api
  module V1
    class UsersController < ApplicationController
      include Pagy::Backend

      before_action :set_user, only: %i[show update destroy toggle_active reset_password]

      def me
        skip_authorization
        render json: UserBlueprint.render_as_hash(current_user)
      end

      def index
        authorize User
        users = @organization.users.order(:first_name, :last_name)
        users = users.where(role: params[:role])   if params[:role].present?
        users = users.where(active: params[:active]) if params[:active].present?

        # Paginação opcional: se per_page=all (ou não informado), retorna todos
        # para compatibilidade com selects/dropdowns do frontend.
        if params[:per_page].present? && params[:per_page] != "all"
          @pagy, users = pagy(users, limit: params[:per_page].to_i)
          render json: {
            users:      UserBlueprint.render_as_hash(users),
            pagination: pagy_metadata(@pagy)
          }
        else
          render json: UserBlueprint.render_as_hash(users)
        end
      end

      def show
        authorize @user
        render json: UserBlueprint.render_as_hash(@user)
      end

      def create
        authorize User
        # Gera senha temporária se o admin não forneceu uma
        auto_password = user_params[:password].blank? ? SecureRandom.hex(12) : nil
        user = @organization.users.new(user_params)
        user.password = auto_password if auto_password
        user.save!
        # Sempre envia e-mail de boas-vindas via MailerSend (mesmo pipeline do SLA digest)
        # auto_password é nil quando o admin definiu a senha — o template cuida disso
        TicketMailer.welcome(user, auto_password).deliver_later
        render json: UserBlueprint.render_as_hash(user), status: :created
      end

      def update
        authorize @user
        @user.update!(user_params)
        render json: UserBlueprint.render_as_hash(@user)
      end

      def destroy
        authorize @user
        @user.destroy!
        head :no_content
      end

      def toggle_active
        authorize @user, :toggle_active?
        @user.update!(active: !@user.active)
        render json: UserBlueprint.render_as_hash(@user)
      end

      # GET /api/v1/users/capacity?from=YYYY-MM-DD&to=YYYY-MM-DD
      # Retorna a carga de todos os usuários ativos da organização para o período.
      # Usado pelo frontend para exibir badges de carga no picker de responsável.
      def capacity
        authorize User, :capacity?

        from = params[:from].present? ? Date.parse(params[:from]) : Date.current
        to   = params[:to].present?   ? Date.parse(params[:to])   : from + 6

        users = @organization.users.where(active: true).order(:first_name, :last_name)

        # Cache por versão de org: bust automático quando ScheduledDays mudam.
        version  = capacity_cache_version
        cache_key = "user_capacity/#{@organization.id}/v#{version}/#{from}/#{to}"
        data = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
          UserCapacityService.call(
            users:        users,
            organization: @organization,
            from:         from,
            to:           to
          )
        end

        render json: data
      rescue ArgumentError => e
        render json: { error: "Parâmetro de data inválido: #{e.message}" }, status: :bad_request
      end

      def reset_password
        authorize @user, :reset_password?
        new_password = SecureRandom.hex(8)
        @user.update!(password: new_password)
        TicketMailer.welcome(@user, new_password).deliver_later
        render json: { message: "Senha redefinida. E-mail sendo enviado para #{@user.email}." }
      end

      private

      def capacity_cache_version
        Rails.cache.fetch("capacity_version/#{@organization.id}", expires_in: 24.hours) do
          SecureRandom.hex(4)
        end
      end

      def set_user
        @user = @organization.users.find(params[:id])
      end

      def user_params
        params.require(:user).permit(
          :first_name, :last_name, :email, :role,
          :password, :active, :available_hours, :max_hours_per_ticket,
          :avatar_color
        )
      end
    end
  end
end
