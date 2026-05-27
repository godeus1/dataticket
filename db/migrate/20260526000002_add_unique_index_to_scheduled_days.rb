class AddUniqueIndexToScheduledDays < ActiveRecord::Migration[8.0]
  def up
    # Remove duplicate rows before adding the unique constraint.
    # Keep only the row with the highest id (most recently created) per (ticket, user, date).
    execute <<~SQL
      DELETE FROM scheduled_days
      WHERE id NOT IN (
        SELECT MAX(id)
        FROM scheduled_days
        GROUP BY ticket_id, user_id, date
      )
    SQL

    add_index :scheduled_days, %i[ticket_id user_id date],
              unique: true,
              name:   "idx_scheduled_days_unique_ticket_user_date"
  end

  def down
    remove_index :scheduled_days, name: "idx_scheduled_days_unique_ticket_user_date"
  end
end
