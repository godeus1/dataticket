# AgendaSchedulerService — simula a agenda do responsável e calcula prazos reais.
#
# Algoritmo:
#   1. Carrega todos os tickets ativos do responsável (status ≠ Resolvido/Fechado)
#   2. Ordena por prioridade (menor sla_hours = mais crítico vem primeiro),
#      desempate por created_at (ticket mais antigo tem precedência)
#   3. Simula dia a dia (dias úteis, ignorando fins de semana e feriados):
#      - Cada dia aloca até `available_hours` do responsável no total
#      - Cada ticket recebe no máximo `max_hours_per_ticket` por dia
#      - Tickets de maior prioridade preenchem o dia antes dos de menor
#   4. O prazo de cada ticket = último dia em que ele recebe horas na simulação
#
# Retorna um Result com:
#   #deadline_for(key)          → Date ou nil
#   #days_for(key)              → { Date => Float (horas) }
#   key = ticket.id ou FOCUS_KEY (para o focus_ticket passado via call)

class AgendaSchedulerService
  FOCUS_KEY   = :__focus__
  MAX_DAYS    = 730   # segurança contra loop infinito (~2 anos)
  WORK_START  = 8     # hora de início do expediente (usado apenas no SlaCalculator)
  WORK_END    = 18    # hora de fim do expediente

  Result = Struct.new(:deadlines, :daily_allocations, keyword_init: true) do
    def deadline_for(key) = deadlines[key]
    def days_for(key)     = daily_allocations.fetch(key, {})
  end

  def initialize(assignee, organization)
    @assignee     = assignee
    @organization = organization
  end

  # focus_ticket: o ticket que está sendo triado/atualizado.
  #   Pode não estar salvo ainda (sem id) ou ter atributos ainda não persistidos.
  #   É identificado por identidade de objeto (equal?) para suportar ambos os casos.
  def call(focus_ticket: nil)
    tickets        = build_sorted_ticket_list(focus_ticket)
    avail          = @assignee.available_hours.to_f.clamp(0.1, 24.0)
    max_per_ticket = @assignee.max_hours_per_ticket.to_f.clamp(0.1, avail)
    holidays       = load_holidays

    remaining          = build_remaining(tickets, focus_ticket)
    daily_allocations  = Hash.new { |h, k| h[k] = {} }
    last_day           = {}

    date = start_date(focus_ticket)
    iter = 0

    while remaining.values.any? { |v| v > 0.009 } && iter < MAX_DAYS
      iter += 1

      unless working_day?(date, holidays)
        date += 1
        next
      end

      day_used = 0.0

      tickets.each do |ticket|
        k = key_for(ticket, focus_ticket)
        rem = remaining[k] || 0
        next if rem < 0.01
        break if day_used >= avail - 0.009

        hours = [max_per_ticket, avail - day_used, rem].min.round(2)
        next if hours < 0.01

        remaining[k]              -= hours
        day_used                  += hours
        last_day[k]                = date
        daily_allocations[k][date] = hours
      end

      date += 1
    end

    Result.new(deadlines: last_day, daily_allocations: daily_allocations)
  end

  private

  # ── Helpers ──────────────────────────────────────────────────────────────

  def build_sorted_ticket_list(focus_ticket)
    # Carrega apenas tickets ativos COM esforço estimado > 0.
    # Tickets sem esforço não têm trabalho a alocar e não devem participar da simulação.
    active = @organization.tickets
                          .where(assignee_id: @assignee.id)
                          .where.not(status: %w[Resolvido Fechado])
                          .where(deleted_at: nil)
                          .where("effort_estimated > 0")
                          .includes(:priority)
                          .to_a

    # Substitui pelo focus_ticket (com atributos atualizados) se já existir no DB
    if focus_ticket
      active.reject! { |t| t.id && t.id == focus_ticket.id }
      # Só inclui o focus_ticket se ele tiver esforço estimado
      active << focus_ticket if focus_ticket.effort_estimated.to_f > 0
    end

    # Ordena: menor sla_hours primeiro (crítico > alta > média > baixa)
    # Desempate: created_at mais antigo tem precedência (tickets mais antigos são atendidos antes)
    active.sort_by! do |t|
      sla = t.priority&.sla_hours&.to_f || 999_999.0
      ts  = (focus_ticket && t.equal?(focus_ticket)) ? Time.current : (t.created_at || Time.current)
      [sla, ts]
    end

    active
  end

  def build_remaining(tickets, focus_ticket)
    tickets.each_with_object({}) do |t, h|
      k      = key_for(t, focus_ticket)
      effort = t.effort_estimated.to_f
      used   = t.effort_used.to_f
      rem    = [effort - used, 0.0].max
      # Apenas inclui no mapa tickets que realmente têm trabalho pendente.
      # Tickets sem esforço estimado (effort = 0) não devem aparecer na simulação.
      h[k] = rem if effort > 0
    end
  end

  def key_for(ticket, focus_ticket)
    (focus_ticket && ticket.equal?(focus_ticket)) ? FOCUS_KEY : ticket.id
  end

  def start_date(focus_ticket)
    # Nunca agenda no passado; começa hoje ou na data de abertura, o que for mais tarde
    opening = focus_ticket&.created_at&.to_date || Date.current
    [opening, Date.current].max
  end

  def load_holidays
    @organization.holidays.map do |h|
      { recurring: h.recurring, date: h.date.to_date }
    end
  end

  def working_day?(date, holidays)
    return false if date.saturday? || date.sunday?

    holidays.none? do |h|
      if h[:recurring]
        h[:date].month == date.month && h[:date].day == date.day
      else
        h[:date] == date
      end
    end
  end
end
