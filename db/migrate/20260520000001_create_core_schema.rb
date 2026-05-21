class CreateCoreSchema < ActiveRecord::Migration[8.1]
  def change
    # ── Organizations ──────────────────────────────────────────────────────────
    create_table :organizations do |t|
      t.string  :name,           null: false
      t.string  :slug,           null: false
      t.string  :timezone,       default: "America/Sao_Paulo"
      t.string  :date_format,    default: "DD/MM/YYYY"
      t.boolean :emails_enabled, default: false
      t.string  :smtp_host
      t.integer :smtp_port,      default: 587
      t.string  :smtp_user
      t.timestamps
    end
    add_index :organizations, :slug, unique: true

    # ── Users ──────────────────────────────────────────────────────────────────
    create_table :users do |t|
      t.references :organization,      null: false, foreign_key: true
      t.string  :email,                null: false
      t.string  :encrypted_password,   null: false, default: ""
      t.string  :first_name,           null: false
      t.string  :last_name,            null: false
      t.string  :role,                 null: false, default: "user"
      t.boolean :active,               default: true
      t.decimal :available_hours,      default: 8.0,  precision: 5, scale: 2
      t.decimal :max_hours_per_ticket, default: 4.0,  precision: 5, scale: 2
      t.string  :avatar_initials
      t.string  :avatar_color
      t.string  :jti,                  null: false
      t.timestamps
    end
    add_index :users, [ :email, :organization_id ], unique: true
    add_index :users, :jti, unique: true

    # ── Categories ─────────────────────────────────────────────────────────────
    create_table :categories do |t|
      t.references :organization, null: false, foreign_key: true
      t.string  :name,   null: false
      t.string  :color,  default: "#2383e2"
      t.boolean :active, default: true
      t.timestamps
    end

    # ── Priorities ─────────────────────────────────────────────────────────────
    create_table :priorities do |t|
      t.references :organization, null: false, foreign_key: true
      t.string  :name,     null: false
      t.string  :color,    default: "#6b7280"
      t.integer :sla_hours, default: 48
      t.decimal :sla_days,  default: 2.0, precision: 5, scale: 2
      t.integer :position,  default: 0
      t.boolean :active,    default: true
      t.timestamps
    end

    # ── Queues ─────────────────────────────────────────────────────────────────
    create_table :queues do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :category,                 foreign_key: true
      t.string  :name,   null: false
      t.boolean :active, default: true
      t.timestamps
    end

    create_table :queue_memberships do |t|
      t.references :queue, null: false, foreign_key: true
      t.references :user,  null: false, foreign_key: true
      t.timestamps
    end
    add_index :queue_memberships, [ :queue_id, :user_id ], unique: true

    # ── Tickets (PK string: "TK-0001") ────────────────────────────────────────
    create_table :tickets, id: false do |t|
      t.string     :id,           null: false, primary_key: true
      t.references :organization, null: false, foreign_key: true
      t.bigint     :requester_id, null: false
      t.bigint     :assignee_id
      t.references :category,                 foreign_key: true
      t.references :priority,                 foreign_key: true
      t.references :queue,                    foreign_key: true
      t.string  :title,             null: false
      t.text    :description
      t.string  :status,            null: false, default: "Não iniciado"
      t.boolean :triaged,           default: false
      t.decimal :effort_estimated,  default: 0, precision: 6, scale: 2
      t.decimal :effort_used,       default: 0, precision: 6, scale: 2
      t.datetime :deadline
      t.datetime :triaged_at
      t.datetime :resolved_at
      t.timestamps
    end
    add_foreign_key :tickets, :users, column: :requester_id
    add_foreign_key :tickets, :users, column: :assignee_id
    add_index :tickets, :status
    add_index :tickets, :deadline
    add_index :tickets, :created_at
    add_index :tickets, [ :organization_id, :status ]
    add_index :tickets, [ :assignee_id,     :status ]

    # ── Ticket Comments ────────────────────────────────────────────────────────
    create_table :ticket_comments do |t|
      t.string     :ticket_id, null: false
      t.references :user,      null: false, foreign_key: true
      t.text   :body, null: false
      t.string :kind, default: "public"
      t.timestamps
    end
    add_foreign_key :ticket_comments, :tickets
    add_index :ticket_comments, :ticket_id

    # ── Ticket Histories ───────────────────────────────────────────────────────
    create_table :ticket_histories do |t|
      t.string     :ticket_id, null: false
      t.references :user,      null: false, foreign_key: true
      t.string :field
      t.string :from_value
      t.string :to_value
      t.timestamps
    end
    add_foreign_key :ticket_histories, :tickets
    add_index :ticket_histories, :ticket_id

    # ── Ticket Attachments ─────────────────────────────────────────────────────
    create_table :ticket_attachments do |t|
      t.string     :ticket_id, null: false
      t.references :user,      null: false, foreign_key: true
      t.string  :filename,     null: false
      t.integer :byte_size
      t.string  :content_type
      t.string  :storage_key
      t.timestamps
    end
    add_foreign_key :ticket_attachments, :tickets

    # ── Notifications ──────────────────────────────────────────────────────────
    create_table :notifications do |t|
      t.references :user,  null: false, foreign_key: true
      t.string     :ticket_id
      t.string  :title, null: false
      t.text    :body
      t.string  :kind
      t.boolean :read, default: false
      t.timestamps
    end
    add_foreign_key :notifications, :tickets, column: :ticket_id
    add_index :notifications, [ :user_id, :read ]

    # ── Holidays ───────────────────────────────────────────────────────────────
    create_table :holidays do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.date   :date, null: false
      t.string :kind, default: "Nacional"
      t.timestamps
    end

    # ── Audit Logs ─────────────────────────────────────────────────────────────
    create_table :audit_logs do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user,                     foreign_key: true
      t.string :action,       null: false
      t.string :entity
      t.string :entity_id
      t.jsonb  :changes_data, default: {}
      t.timestamps
    end
    add_index :audit_logs, :created_at
    add_index :audit_logs, [ :organization_id, :created_at ]

    # ── Articles (KB) ──────────────────────────────────────────────────────────
    create_table :articles do |t|
      t.references :organization, null: false, foreign_key: true
      t.bigint     :author_id,    null: false
      t.string  :title,     null: false
      t.text    :content
      t.string  :keywords
      t.boolean :published, default: false
      t.timestamps
    end
    add_foreign_key :articles, :users, column: :author_id

    # ── Scheduled Days (alocação de horas/dia por ticket) ──────────────────────
    create_table :scheduled_days do |t|
      t.string     :ticket_id, null: false
      t.references :user,      null: false, foreign_key: true
      t.date    :date,  null: false
      t.decimal :hours, null: false, precision: 5, scale: 2
      t.timestamps
    end
    add_foreign_key :scheduled_days, :tickets
    add_index :scheduled_days, [ :ticket_id, :date ]

    # ── JWT Denylist ───────────────────────────────────────────────────────────
    create_table :jwt_denylist do |t|
      t.string   :jti, null: false
      t.datetime :exp, null: false
    end
    add_index :jwt_denylist, :jti
  end
end
