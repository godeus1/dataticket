# ScheduleReallocationService
#
# Recalcula prazos e ScheduledDays para TODOS os tickets ativos do responsável.
#
# Chamado sempre que o cenário de esforço muda:
#   - Cronômetro pausado (effort_used sobe → remaining cai)
#   - Ticket resolvido/fechado (remove este ticket da agenda)
#   - Esforço estimado ou prioridade editados manualmente
#   - Responsável reatribuído
#
# GARANTIAS:
#   1. A soma de horas agendadas por dia nunca excede available_hours do responsável.
#   2. Tickets com remaining = 0 (esforço consumido) têm seus dias futuros limpos.
#   3. Tickets não mais ativos (Resolvido/Fechado) já foram limpos por release_capacity!.
#
class ScheduleReallocationService
  def initialize(assignee, organization)
    @assignee     = assignee
    @organization = organization
  end

  def call
    return unless @assignee.present?

    result = AgendaSchedulerService.new(@assignee, @organization).call

    # IDs de todos os tickets ativos para este responsável
    all_active_ids = @organization.tickets
                                  .where(assignee_id: @assignee.id)
                                  .where.not(status: %w[Resolvido Fechado])
                                  .where(deleted_at: nil)
                                  .pluck(:id)
                                  .map(&:to_s)

    # IDs que receberam alocação nesta simulação
    scheduled_ids = result.deadlines
                          .keys
                          .reject { |k| k == AgendaSchedulerService::FOCUS_KEY }
                          .map(&:to_s)

    # Tickets ativos mas SEM alocação (remaining ≈ 0) → limpar dias futuros residuais
    zero_remaining_ids = all_active_ids - scheduled_ids

    ActiveRecord::Base.transaction do
      # 1. Limpa resíduos de tickets com esforço totalmente consumido
      if zero_remaining_ids.any?
        ScheduledDay
          .where(user_id: @assignee.id, ticket_id: zero_remaining_ids)
          .where("date >= ?", Date.current)
          .destroy_all
      end

      # 2. Aplica o novo plano para tickets que ainda têm trabalho pendente
      result.deadlines.each do |ticket_id, date|
        next if ticket_id == AgendaSchedulerService::FOCUS_KEY

        ticket = @organization.tickets.find_by(id: ticket_id)
        next unless ticket

        deadline_dt = date&.to_time&.end_of_day&.in_time_zone
        ticket.update_columns(deadline: deadline_dt) if deadline_dt

        # daily_allocations nunca é vazio para tickets em result.deadlines
        days = result.daily_allocations[ticket_id] || {}
        ScheduleService.new(ticket, days).schedule
      end
    end

    result
  rescue StandardError => e
    Rails.logger.error("[ScheduleReallocationService] #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    nil
  end
end
