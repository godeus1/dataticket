class QueueMonitorJob < ApplicationJob
  queue_as :default

  # Limiar de jobs com falha antes de reportar ao Sentry
  FAILURE_ALERT_THRESHOLD = 5

  def perform
    stats = collect_stats
    log_stats(stats)
    alert_if_needed(stats)
  end

  private

  def collect_stats
    {
      failed:  failed_count,
      blocked: blocked_count,
      ready:   ready_count,
      checked_at: Time.current.iso8601
    }
  rescue StandardError => e
    Rails.logger.error("[QueueMonitorJob] Erro ao coletar stats: #{e.message}")
    {}
  end

  def failed_count
    SolidQueue::FailedExecution.count
  rescue NameError
    # SolidQueue não está disponível (ex: testes sem tabelas)
    0
  end

  def blocked_count
    SolidQueue::BlockedExecution.count
  rescue NameError
    0
  end

  def ready_count
    SolidQueue::ReadyExecution.count
  rescue NameError
    0
  end

  def log_stats(stats)
    return if stats.empty?

    level = stats[:failed].to_i >= FAILURE_ALERT_THRESHOLD ? :warn : :info
    Rails.logger.public_send(
      level,
      "[QueueMonitorJob] failed=#{stats[:failed]} blocked=#{stats[:blocked]} ready=#{stats[:ready]}"
    )
  end

  def alert_if_needed(stats)
    return if stats.empty?
    return unless stats[:failed].to_i >= FAILURE_ALERT_THRESHOLD

    message = "Solid Queue: #{stats[:failed]} jobs com falha (limiar: #{FAILURE_ALERT_THRESHOLD})"

    # Reporta ao Sentry se configurado
    if defined?(Sentry)
      Sentry.capture_message(message, level: :warning, extra: stats)
    end

    Rails.logger.warn("[QueueMonitorJob] ALERTA: #{message}")
  end
end
