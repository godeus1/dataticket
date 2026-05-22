module Api
  module V1
    class NotificationsController < ApplicationController
      include Pagy::Backend

      before_action :set_notification, only: %i[update]

      def index
        authorize Notification
        notifications = current_user.notifications.recent
        notifications = notifications.unread if params[:unread] == "true"
        @pagy, notifications = pagy(notifications, limit: params.fetch(:per_page, 30).to_i)
        render json: {
          notifications: NotificationBlueprint.render_as_hash(notifications),
          pagination:    pagy_metadata(@pagy)
        }
      end

      def update
        authorize @notification
        @notification.update!(notification_params)
        render json: NotificationBlueprint.render_as_hash(@notification)
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
