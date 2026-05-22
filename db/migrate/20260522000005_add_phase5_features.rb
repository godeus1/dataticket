class AddPhase5Features < ActiveRecord::Migration[8.1]
  def change
    # ── Tags ────────────────────────────────────────────────────────────────
    create_table :tags do |t|
      t.references :organization, null: false, foreign_key: true
      t.string  :name,  null: false
      t.string  :color, default: "#6b7280", null: false
      t.timestamps
    end
    add_index :tags, %i[organization_id name], unique: true

    # ── Ticket ↔ Tag (join) — ticket_id é string pois tickets.id é varchar ──
    create_table :ticket_tags do |t|
      t.string     :ticket_id, null: false   # FK manual (string PK)
      t.references :tag,       null: false, foreign_key: true
      t.timestamps
    end
    add_index :ticket_tags, %i[ticket_id tag_id], unique: true
    add_foreign_key :ticket_tags, :tickets, column: :ticket_id, primary_key: :id

    # ── Custom Fields (definição por organização) ────────────────────────────
    create_table :custom_fields do |t|
      t.references :organization, null: false, foreign_key: true
      t.string  :name,       null: false
      t.string  :field_type, null: false, default: "text"
      t.jsonb   :options,    default: [], null: false
      t.boolean :required,   default: false, null: false
      t.integer :position,   default: 0,     null: false
      t.boolean :active,     default: true,  null: false
      t.timestamps
    end
    add_index :custom_fields, %i[organization_id position]

    # ── Ticket Field Values — ticket_id é string ─────────────────────────────
    create_table :ticket_field_values do |t|
      t.string     :ticket_id,      null: false   # FK manual (string PK)
      t.references :custom_field,   null: false, foreign_key: true
      t.text :value
      t.timestamps
    end
    add_index :ticket_field_values, %i[ticket_id custom_field_id], unique: true
    add_foreign_key :ticket_field_values, :tickets, column: :ticket_id, primary_key: :id
  end
end
