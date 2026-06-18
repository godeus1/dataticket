class AddSoftDeleteToTicketAttachments < ActiveRecord::Migration[8.1]
  # Soft delete de anexos: vão para a lixeira (deleted_at) e podem ser
  # restaurados em até 30 dias. Só gestor/admin deleta e restaura.
  def change
    add_column :ticket_attachments, :deleted_at,    :datetime
    add_column :ticket_attachments, :deleted_by_id, :bigint

    add_index :ticket_attachments, [ :ticket_id, :deleted_at ]
    add_index :ticket_attachments, :deleted_by_id
    add_foreign_key :ticket_attachments, :users, column: :deleted_by_id
  end
end
