class CreateTicketAssignees < ActiveRecord::Migration[8.1]
  def change
    create_table :ticket_assignees do |t|
      t.references :ticket, null: false, type: :string, foreign_key: true, index: true
      t.references :user,   null: false, foreign_key: true, index: true
      t.timestamps
    end
    add_index :ticket_assignees, [:ticket_id, :user_id], unique: true
  end
end
