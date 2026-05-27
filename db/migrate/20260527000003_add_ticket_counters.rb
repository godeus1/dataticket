class AddTicketCounters < ActiveRecord::Migration[8.1]
  def up
    create_table :ticket_counters, id: false do |t|
      t.bigint  :organization_id, null: false
      t.integer :counter,         null: false, default: 0
    end
    add_index :ticket_counters, :organization_id, unique: true
    add_foreign_key :ticket_counters, :organizations

    # Seed current max ticket number per org from existing tickets.
    # Uses the same regex/cast as the old generate_ticket_id to guarantee
    # the next ticket created will continue from where the sequence left off.
    execute <<~SQL
      INSERT INTO ticket_counters (organization_id, counter)
      SELECT
        organization_id,
        COALESCE(MAX(CAST(SUBSTRING(id, 4) AS INTEGER)), 0)
      FROM tickets
      WHERE id ~ '^TK-\\d+$'
      GROUP BY organization_id
    SQL

    # Orgs with zero tickets get a counter row so the ON CONFLICT path always works.
    execute <<~SQL
      INSERT INTO ticket_counters (organization_id, counter)
      SELECT id, 0
      FROM organizations
      WHERE id NOT IN (SELECT organization_id FROM ticket_counters)
    SQL
  end

  def down
    drop_table :ticket_counters
  end
end
