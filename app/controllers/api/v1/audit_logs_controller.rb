module Api
  module V1
    class AuditLogsController < ApplicationController
      def index
        authorize AuditLog
        logs = @organization.audit_logs.includes(:user).recent
        logs = logs.where(action: params[:action]) if params[:action].present?
        logs = logs.where(user_id: params[:user_id]) if params[:user_id].present?
        logs = logs.where("created_at >= ?", params[:from]) if params[:from].present?
        logs = logs.where("created_at <= ?", params[:to]) if params[:to].present?

        render json: logs.as_json(
          only: %i[id action details ticket_id created_at],
          include: { user: { only: %i[id first_name last_name email] } }
        )
      end
    end
  end
end
