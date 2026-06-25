module Api
  module V1
    class AuditLogsController < ApplicationController
      def index
        authorize AuditLog

        logs = @organization.audit_logs.includes(:user).recent
        # ATENÇÃO: NÃO usar params[:action] — é reservado pelo Rails (= "index")
        # e fazia o filtro casar com action "index", zerando o resultado.
        logs = logs.where(action:   params[:log_action])              if params[:log_action].present?
        logs = logs.where(entity:   params[:entity])                  if params[:entity].present?
        logs = logs.where(user_id:  params[:user_id])                 if params[:user_id].present?
        logs = logs.where("created_at >= ?", params[:from].to_time)   if params[:from].present?
        logs = logs.where("created_at <= ?", params[:to].to_time)     if params[:to].present?
        logs = logs.limit(500)

        render json: logs.as_json(
          only: %i[id action entity entity_id changes_data created_at],
          include: { user: { only: %i[id first_name last_name email] } }
        )
      end
    end
  end
end
