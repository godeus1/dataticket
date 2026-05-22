class AddPhase5Governance < ActiveRecord::Migration[8.1]
  def change
    # ── Accounts (MSP top-level tenant) ────────────────────────────────────
    create_table :accounts do |t|
      t.string  :name,  null: false
      t.string  :slug,  null: false
      t.string  :plan,  null: false, default: "standard"  # standard | enterprise
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :accounts, :slug, unique: true

    # Organizations can belong to an Account (MSP mode)
    add_column :organizations, :account_id, :bigint
    add_index  :organizations, :account_id
    add_foreign_key :organizations, :accounts, column: :account_id

    # ── SSO Configurations (per organization) ──────────────────────────────
    # NOTE: t.references already creates index on organization_id
    create_table :sso_configurations do |t|
      t.references :organization, null: false, foreign_key: true, index: { unique: true }
      t.string  :idp_entity_id,   null: false
      t.string  :idp_sso_url,     null: false
      t.text    :idp_cert,        null: false
      t.string  :sp_entity_id,    null: false
      t.string  :name_id_format,  default: "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
      t.boolean :active,          default: true, null: false
      t.timestamps
    end

    # ── Event Sourcing ──────────────────────────────────────────────────────
    create_table :events do |t|
      t.string   :aggregate_type, null: false
      t.string   :aggregate_id,   null: false
      t.string   :event_type,     null: false
      t.jsonb    :payload,        null: false, default: {}
      t.references :actor,        foreign_key: { to_table: :users }, index: true
      # NOTE: organization_id index created by t.references below
      t.references :organization, null: false, foreign_key: true
      t.datetime :occurred_at,    null: false
      t.integer  :version,        null: false, default: 1
      t.timestamps
    end
    add_index :events, %i[aggregate_type aggregate_id]
    add_index :events, %i[organization_id event_type]
    add_index :events, :occurred_at
  end
end
