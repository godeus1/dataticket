# Centraliza a adição de horas de esforço a um ticket (botão "+ Horas",
# triagem e reabertura). Cada adição:
#   - cria um registro EffortAddition (alimenta a lista lateral),
#   - soma as horas em effort_estimated,
#   - registra no histórico do ticket,
#   - opcionalmente cria um comentário automático com a justificativa (prova).
class EffortAdditionService
  def self.add(ticket:, user:, hours:, reason: nil, source: "manual")
    hours = hours.to_f.round(2)
    return nil unless hours > 0

    addition = nil
    ActiveRecord::Base.transaction do
      old_effort = ticket.effort_estimated.to_f
      new_effort = (old_effort + hours).round(2)

      # A justificativa fica registrada apenas na própria adição (lista lateral)
      # e no histórico — não gera comentário (não deve ir ao solicitante).
      addition = ticket.effort_additions.create!(
        user:   user,
        hours:  hours,
        reason: reason.presence,
        source: source
      )

      ticket.update!(effort_estimated: new_effort)

      # Histórico (aparece na aba "Histórico" do ticket)
      ticket.histories.create!(
        user:       user,
        field:      "Esforço adicional",
        from_value: "+#{fmt(hours)} h",
        to_value:   reason.presence || source_label(source)
      )
    end

    addition
  end

  # Remove uma adição e estorna as horas do esforço estimado.
  def self.remove(addition:)
    ActiveRecord::Base.transaction do
      ticket = addition.ticket.reload # evita esforço stale na associação em cache
      new_effort = [ (ticket.effort_estimated.to_f - addition.hours.to_f).round(2), 0 ].max
      ticket.update!(effort_estimated: new_effort)
      addition.destroy!
    end
  end

  def self.fmt(h)
    h == h.to_i ? h.to_i.to_s : format("%.2f", h)
  end

  def self.source_label(source)
    { "manual" => "Adição manual", "triage" => "Triagem", "reopen" => "Reabertura" }[source.to_s] || source.to_s
  end
end
