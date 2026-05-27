class UpdateTicketTimerSessionsForRunningState < ActiveRecord::Migration[8.0]
  def up
    # Make stopped_at and duration_mins nullable so a running (not yet stopped) session can be stored
    change_column_null :ticket_timer_sessions, :stopped_at,    true
    change_column_null :ticket_timer_sessions, :duration_mins, true

    # status: 'running' | 'completed' | 'cancelled'
    add_column :ticket_timer_sessions, :status, :string, null: false, default: 'completed'

    # Efficient lookup of a user's running session
    add_index :ticket_timer_sessions, [ :user_id, :status ], name: 'idx_timer_sessions_user_status'
  end

  def down
    remove_index  :ticket_timer_sessions, name: 'idx_timer_sessions_user_status'
    remove_column :ticket_timer_sessions, :status

    change_column_null :ticket_timer_sessions, :stopped_at,    false
    change_column_null :ticket_timer_sessions, :duration_mins, false
  end
end
