module Api
  module V1
    class NotificationsController < ApplicationController
      before_action :set_notification, only: %i[update]

      def index
        authorize Notification
        notifications = current_user.notifications.recent
        notifications = notifications.unread if params[:unread] == "true"
        render json: notifications.as_json(
          only: %i[id title body kind read ticket_id created_at]
        )
      end

      def update
        authorize @notification
        @notification.update!(notification_params)
        render json: @notification.as_json(only: %i[id title body kind read ticket_id created_at])
      end

      def mark_all_read
        authorize Notification
        current_user.notifications.unread.update_all(read: true)
        render json: { message: "Todas as notificações marcadas como lidas" }
      end

      private

      def set_notification
        @notification = current_user.notifications.find(params[:id])
      end

      def notification_params
        params.require(:notification).permit(:read)
      end
    end
  end
end
