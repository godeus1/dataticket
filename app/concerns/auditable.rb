module Auditable
  extend ActiveSupport::Concern

  # Cria um registro de AuditLog no banco, respeitando o toggle do tipo de evento
  # configurado na empresa. Silencia erros para nunca quebrar a requisição principal.
  def audit!(event:, action:, entity:, entity_id: nil, changes: {})
    @organization.record_audit(
      event:     event,
      action:    action,
      entity:    entity,
      entity_id: entity_id,
      changes:   changes,
      user:      current_user
    )
  end
end
