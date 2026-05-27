class CreateTicketTimerSessions < ActiveRecord::Migration[8.0]
  def change
    # Guard: tabela pode já existir se criada via db:schema:load ou psql manual.
    unless table_exists?(:ticket_timer_sessions)
      create_table :ticket_timer_sessions do |t|
        # ticket_id deve ser string para corresponder a tickets.id (varchar)
        t.references :ticket, null: false, type: :string, index: true
        t.references :user,   null: false, index: true
        t.datetime   :started_at,    null: false
        t.datetime   :stopped_at,    null: false
        t.float      :duration_mins, null: false, default: 0.0

        t.timestamps
      end

      add_foreign_key :ticket_timer_sessions, :tickets, if_not_exists: true
      add_foreign_key :ticket_timer_sessions, :users,   if_not_exists: true
    end

    unless index_exists?(:ticket_timer_sessions, %i[ticket_id started_at])
      add_index :ticket_timer_sessions, %i[ticket_id started_at]
    end
  end
end
