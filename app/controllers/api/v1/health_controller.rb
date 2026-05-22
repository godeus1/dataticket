module Api
  module V1
    class HealthController < ActionController::API
      def index
        db_check    = check_database
        queue_check = check_queue

        overall = (db_check[:status] == "ok" && queue_check[:status] == "ok") ? "ok" : "degraded"

        render json: {
          status:    overall,
          version:   "1.0",
          timestamp: Time.current.iso8601,
          checks:    {
            database: db_check,
            queue:    queue_check
          }
        }, status: (overall == "ok" ? :ok : :service_unavailable)
      end

      private

      def check_database
        ActiveRecord::Base.connection.execute("SELECT 1")
        { status: "ok" }
      rescue StandardError => e
        { status: "error", error: e.message }
      end

      def check_queue
        failed  = SolidQueue::FailedExecution.count
        blocked = SolidQueue::BlockedExecution.count
        status  = failed >= QueueMonitorJob::FAILURE_ALERT_THRESHOLD ? "degraded" : "ok"

        { status: status, failed_jobs: failed, blocked_jobs: blocked }
      rescue ActiveRecord::StatementInvalid, PG::UndefinedTable
        # Tabelas do Solid Queue não existem neste ambiente (ex: dev sem db:migrate completo)
        { status: "ok", failed_jobs: 0, blocked_jobs: 0, note: "solid_queue not migrated" }
      rescue StandardError => e
        { status: "unknown", error: e.message }
      end
    end
  end
end
