class CreateTicketTimerSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :ticket_timer_sessions do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :user,   null: false, foreign_key: true
      t.datetime   :started_at,    null: false
      t.datetime   :stopped_at,    null: false
      t.float      :duration_mins, null: false, default: 0.0

      t.timestamps
    end

    add_index :ticket_timer_sessions, [:ticket_id, :started_at]
  end
end
