class AddPhase4Features < ActiveRecord::Migration[8.1]
  def change
    # ── Triage Rules ────────────────────────────────────────────────────────
    create_table :triage_rules do |t|
      t.references :organization, null: false, foreign_key: true
      t.string     :name,         null: false
      t.string     :keyword,      null: false   # matched against title + description
      t.references :category,     foreign_key: true
      t.references :priority,     foreign_key: true
      t.references :queue,        foreign_key: { to_table: :queues }
      t.integer    :position,     default: 0, null: false
      t.boolean    :active,       default: true, null: false
      t.timestamps
    end
    add_index :triage_rules, %i[organization_id position]

    # ── Webhook Endpoints ────────────────────────────────────────────────────
    create_table :webhook_endpoints do |t|
      t.references :organization, null: false, foreign_key: true
      t.string   :name,           null: false
      t.string   :url,            null: false
      t.string   :secret                       # HMAC-SHA256 signing secret
      t.string   :events,         array: true, default: []
      t.boolean  :active,         default: true, null: false
      t.timestamps
    end
    # (index on organization_id already created by t.references above)

    # ── SLA Policies (by priority + optional category) ───────────────────────
    create_table :sla_policies do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :priority,     foreign_key: true
      t.references :category,     foreign_key: true
      t.integer    :response_hours, null: false   # first response SLA
      t.integer    :resolve_hours,  null: false   # full resolution SLA
      t.boolean    :active,         default: true, null: false
      t.timestamps
    end
    add_index :sla_policies,
              %i[organization_id priority_id category_id],
              unique: true,
              name: "idx_sla_policies_org_priority_category"

    # ── Action Mailbox (inbound e-mail → ticket) ─────────────────────────────
    create_table :action_mailbox_inbound_emails do |t|
      t.integer :status,      default: 0,   null: false
      t.string  :message_id,                null: false
      t.string  :message_checksum,          null: false
      t.timestamps
      t.index   [ :message_id, :message_checksum ], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
    end
  end
end
