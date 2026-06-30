class CreateEffortAdditions < ActiveRecord::Migration[8.1]
  def change
    # Adições de horas de esforço a um ticket (botão "+ Horas", triagem e
    # reabertura). Cada adição guarda a justificativa (prova) e a origem.
    create_table :effort_additions do |t|
      t.string  :ticket_id, null: false
      t.bigint  :user_id,   null: false
      t.decimal :hours,     null: false, precision: 6, scale: 2
      t.text    :reason
      t.string  :source,    null: false, default: "manual" # manual | triage | reopen
      t.timestamps
    end
    add_index :effort_additions, [:ticket_id, :created_at]
    add_index :effort_additions, :user_id
    add_foreign_key :effort_additions, :tickets, column: :ticket_id
    add_foreign_key :effort_additions, :users,   column: :user_id
  end
end
