# frozen_string_literal: true
# Aplica triagem a multiplos tickets de uma vez.
# Apenas tickets com status "Não iniciado" são elegíveis.

class BulkTriageService
  Result = Struct.new(:success?, :triaged, :skipped, :errors, keyword_init: true)

  def initialize(ticket_ids, triage_attrs, actor)
    @ticket_ids   = Array(ticket_ids)
    # Normaliza para Hash puro: triage_attrs pode chegar como ActionController::Parameters
    # (caminho do controller) ou Hash (chamadas internas). ActionController::Parameters.new
    # só aceita Hash, então convertemos antes para evitar erro no caminho real.
    raw = triage_attrs.respond_to?(:to_unsafe_h) ? triage_attrs.to_unsafe_h : triage_attrs.to_h
    @triage_attrs = raw.symbolize_keys.slice(:priority_id, :category_id, :queue_id, :assignee_id)
    @actor        = actor
  end

  def call
    triaged = []
    skipped = []
    errors  = []

    @ticket_ids.each do |tid|
      ticket = Ticket.find_by(id: tid)
      unless ticket
        errors << "#{tid}: nao encontrado"
        next
      end

      # Status canônico COM acento (Ticket::STATUSES). Antes comparava-se com
      # "Nao iniciado" (ASCII), que nunca casava → todos os tickets eram pulados.
      unless ticket.status == "Não iniciado"
        skipped << tid
        next
      end

      result = TriageService.new(ticket, ActionController::Parameters.new(@triage_attrs), @actor).call
      if result.success?
        triaged << tid
      else
        errors << "#{tid}: #{result.errors.join(", ")}"
      end
    end

    Result.new(success?: errors.empty?, triaged: triaged, skipped: skipped, errors: errors)
  end
end
