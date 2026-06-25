class CreateProcessedInboundEmails < ActiveRecord::Migration[8.1]
  def change
    # Deduplicação do poll de e-mails de entrada: guarda o id da mensagem do
    # Graph já processada para não criar comentários duplicados entre ciclos.
    create_table :processed_inbound_emails do |t|
      t.string :message_id, null: false
      t.timestamps
    end
    add_index :processed_inbound_emails, :message_id, unique: true
  end
end
