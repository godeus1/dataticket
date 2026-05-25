module Auditable
  extend ActiveSupport::Concern

  # Cria um registro de AuditLog no banco.
  # Silencia erros para nunca quebrar a requisição principal.
  def audit!(action:, entity:, entity_id: nil, changes: {})
    @organization.audit_logs.create!(
      action:       action,
      entity:       entity,
      entity_id:    entity_id.to_s,
      changes_data: changes.compact,
      user:         current_user
    )
  rescue => e
    Rails.logger.error("[AuditLog] #{action} — #{e.message}")
  end
end
