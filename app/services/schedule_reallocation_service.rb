# ScheduleReallocationService
#
# Redistribui a capacidade do responsável (ScheduledDays) após mudanças de cenário:
#   - Cronômetro pausado (effort_used sobe → remaining cai)
#   - Ticket resolvido/fechado (libera slots ocupados pelos irmãos)
#   - Esforço estimado ou prioridade editados manualmente
#   - Responsável reatribuído
#
# IMPORTANTE — O que este serviço NÃO faz:
#   • Nunca atualiza o campo `deadline` dos tickets irmãos.
#     O prazo visível só muda em ações explícitas do usuário:
#     triagem, reatribuição ou reabertura (via TriageService,
#     TicketsController#reschedule_after_update ou TicketStatusService#reschedule_on_reopen!).
#   • Nunca toca tickets que têm uma sessão de cronômetro ativa (status "running"),
#     pois o analista já iniciou o trabalho e a data comprometida não deve mudar.
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

    # IDs de tickets com cronômetro ativo — intocáveis: prazo E agenda congelados
    running_timer_ticket_ids = running_timer_ids_for_assignee

    ActiveRecord::Base.transaction do
      # 1. Limpa resíduos de tickets com esforço totalmente consumido
      #    (exceto os que têm cronômetro rodando — não interrompemos sessão ativa)
      stoppable_zero = zero_remaining_ids - running_timer_ticket_ids
      if stoppable_zero.any?
        ScheduledDay
          .where(user_id: @assignee.id, ticket_id: stoppable_zero)
          .where("date >= ?", Date.current)
          .destroy_all
      end

      # 2. Redistribui apenas os ScheduledDays (calendário interno de capacidade).
      #    O campo `deadline` NÃO é alterado aqui — prazo só muda em ações explícitas.
      result.deadlines.each do |ticket_id, _date|
        next if ticket_id == AgendaSchedulerService::FOCUS_KEY
        next if running_timer_ticket_ids.include?(ticket_id.to_s)  # cronômetro ativo → pula

        ticket = @organization.tickets.find_by(id: ticket_id)
        next unless ticket

        # Atualiza apenas os ScheduledDays para o planejamento interno de carga.
        # Deadline permanece inalterado — foi definido na triagem/atribuição/reabertura.
        days = result.daily_allocations[ticket_id] || {}
        ScheduleService.new(ticket, days).schedule
      end
    end

    result
  rescue StandardError => e
    Rails.logger.error("[ScheduleReallocationService] #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    nil
  end

  private

  # Retorna os ticket_ids (como strings) que possuem sessão de cronômetro ativa
  # para o responsável atual. Sessões ativas = status "running".
  def running_timer_ids_for_assignee
    return [] unless ActiveRecord::Base.connection.table_exists?(:ticket_timer_sessions)

    TicketTimerSession
      .joins(:ticket)
      .where(tickets: { organization_id: @organization.id, deleted_at: nil })
      .where(user: @assignee, status: "running")
      .pluck(:ticket_id)
      .map(&:to_s)
  rescue StandardError
    []  # falha silenciosa — prefere não bloquear o reallocation
  end
end
