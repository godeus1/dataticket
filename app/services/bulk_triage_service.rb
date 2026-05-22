# frozen_string_literal: true
# Aplica triagem a multiplos tickets de uma vez.
# Apenas tickets com status "Nao iniciado" sao elegíveis.

class BulkTriageService
  Result = Struct.new(:success?, :triaged, :skipped, :errors, keyword_init: true)

  def initialize(ticket_ids, triage_attrs, actor)
    @ticket_ids   = Array(ticket_ids)
    @triage_attrs = triage_attrs.slice(:priority_id, :category_id, :queue_id, :assignee_id)
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

      unless ticket.status == "Nao iniciado"
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
