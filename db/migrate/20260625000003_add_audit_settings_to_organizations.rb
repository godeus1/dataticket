class AddAuditSettingsToOrganizations < ActiveRecord::Migration[8.1]
  def change
    # Quais tipos de evento cada empresa quer registrar no Log de Auditoria.
    # {} = todos ligados (default ON por tipo).
    add_column :organizations, :audit_settings, :jsonb, default: {}, null: false
  end
end
