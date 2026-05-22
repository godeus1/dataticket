module Api
  module V1
    class UsersController < ApplicationController
      before_action :set_user, only: %i[show update destroy toggle_active reset_password]

      def me
        skip_authorization
        render json: UserBlueprint.render_as_hash(current_user)
      end

      def index
        authorize User
        users = @organization.users.order(:first_name, :last_name)
        users = users.where(role: params[:role]) if params[:role].present?
        users = users.where(active: params[:active]) if params[:active].present?
        render json: UserBlueprint.render_as_hash(users)
      end

      def show
        authorize @user
        render json: UserBlueprint.render_as_hash(@user)
      end

      def create
        authorize User
        user = @organization.users.new(user_params)
        user.password = SecureRandom.hex(12) unless user_params[:password].present?
        user.save!
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
        authorize @user, :update?
        @user.update!(active: !@user.active)
        render json: UserBlueprint.render_as_hash(@user)
      end

      def reset_password
        authorize @user, :update?
        new_password = SecureRandom.hex(8)
        @user.update!(password: new_password)
        render json: { message: "Senha redefinida com sucesso" }
      end

      private

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
