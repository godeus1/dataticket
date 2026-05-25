class AddSoftDeleteToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :deleted_at,     :datetime, null: true
    add_column :tickets, :deleted_by_id,  :integer,  null: true
    add_foreign_key :tickets, :users, column: :deleted_by_id
    add_index :tickets, :deleted_at
  end
end
