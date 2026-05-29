class ScheduleService
  # daily_hours: Hash { Date => Float } produzido pelo AgendaSchedulerService.
  #
  # IMPORTANTE: schedule_legacy foi removido intencionalmente.
  # O fallback linear ignorava a capacidade diária dos outros tickets do responsável,
  # causando over-allocation no calendário.
  # Se daily_hours for nil/vazio, apenas limpamos os dias futuros existentes e
  # deixamos o AgendaSchedulerService calcular numa próxima chamada.
  def initialize(ticket, daily_hours = nil)
    @ticket      = ticket
    @daily_hours = daily_hours
  end

  # Aplica a alocação calculada pelo AgendaSchedulerService.
  # Se daily_hours for vazio, apenas limpa os dias futuros (nenhuma nova alocação criada).
  def schedule
    return unless @ticket.assignee.present?

    assignee = @ticket.assignee
    # Apenas dias futuros são replanejados — dias passados são dados históricos
    @ticket.scheduled_days.where(user: assignee).where("date >= ?", Date.current).destroy_all

    # Sem alocação do scheduler → limpar e encerrar.
    # Nunca criar dias linearmente sem respeitar a carga dos outros tickets.
    return if @daily_hours.blank?

    @daily_hours.each do |date, hours|
      next if date < Date.current  # nunca sobrescreve dias já passados
      next if hours.to_f < 0.01   # ignora alocações ínfimas
      @ticket.scheduled_days.create!(user: assignee, date: date, hours: hours.to_f.round(2))
    end
  end
end
