# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_20_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "articles", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.string "keywords"
    t.bigint "organization_id", null: false
    t.boolean "published", default: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_articles_on_organization_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.jsonb "changes_data", default: {}
    t.datetime "created_at", null: false
    t.string "entity"
    t.string "entity_id"
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["organization_id", "created_at"], name: "index_audit_logs_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "color", default: "#2383e2"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_categories_on_organization_id"
  end

  create_table "holidays", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "kind", default: "Nacional"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_holidays_on_organization_id"
  end

  create_table "jwt_denylist", force: :cascade do |t|
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.index ["jti"], name: "index_jwt_denylist_on_jti"
  end

  create_table "notifications", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "kind"
    t.boolean "read", default: false
    t.string "ticket_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "date_format", default: "DD/MM/YYYY"
    t.boolean "emails_enabled", default: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "smtp_host"
    t.integer "smtp_port", default: 587
    t.string "smtp_user"
    t.string "timezone", default: "America/Sao_Paulo"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "priorities", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "color", default: "#6b7280"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.integer "position", default: 0
    t.decimal "sla_days", precision: 5, scale: 2, default: "2.0"
    t.integer "sla_hours", default: 48
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_priorities_on_organization_id"
  end

  create_table "queue_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "queue_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["queue_id", "user_id"], name: "index_queue_memberships_on_queue_id_and_user_id", unique: true
    t.index ["queue_id"], name: "index_queue_memberships_on_queue_id"
    t.index ["user_id"], name: "index_queue_memberships_on_user_id"
  end

  create_table "queues", force: :cascade do |t|
    t.boolean "active", default: true
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_queues_on_category_id"
    t.index ["organization_id"], name: "index_queues_on_organization_id"
  end

  create_table "scheduled_days", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.decimal "hours", precision: 5, scale: 2, null: false
    t.string "ticket_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ticket_id", "date"], name: "index_scheduled_days_on_ticket_id_and_date"
    t.index ["user_id"], name: "index_scheduled_days_on_user_id"
  end

  create_table "ticket_attachments", force: :cascade do |t|
    t.integer "byte_size"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "storage_key"
    t.string "ticket_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_ticket_attachments_on_user_id"
  end

  create_table "ticket_comments", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "kind", default: "public"
    t.string "ticket_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ticket_id"], name: "index_ticket_comments_on_ticket_id"
    t.index ["user_id"], name: "index_ticket_comments_on_user_id"
  end

  create_table "ticket_histories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "field"
    t.string "from_value"
    t.string "ticket_id", null: false
    t.string "to_value"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ticket_id"], name: "index_ticket_histories_on_ticket_id"
    t.index ["user_id"], name: "index_ticket_histories_on_user_id"
  end

  create_table "tickets", id: :string, force: :cascade do |t|
    t.bigint "assignee_id"
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.datetime "deadline"
    t.text "description"
    t.decimal "effort_estimated", precision: 6, scale: 2, default: "0.0"
    t.decimal "effort_used", precision: 6, scale: 2, default: "0.0"
    t.bigint "organization_id", null: false
    t.bigint "priority_id"
    t.bigint "queue_id"
    t.bigint "requester_id", null: false
    t.datetime "resolved_at"
    t.string "status", default: "Não iniciado", null: false
    t.string "title", null: false
    t.boolean "triaged", default: false
    t.datetime "triaged_at"
    t.datetime "updated_at", null: false
    t.index ["assignee_id", "status"], name: "index_tickets_on_assignee_id_and_status"
    t.index ["category_id"], name: "index_tickets_on_category_id"
    t.index ["created_at"], name: "index_tickets_on_created_at"
    t.index ["deadline"], name: "index_tickets_on_deadline"
    t.index ["organization_id", "status"], name: "index_tickets_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_tickets_on_organization_id"
    t.index ["priority_id"], name: "index_tickets_on_priority_id"
    t.index ["queue_id"], name: "index_tickets_on_queue_id"
    t.index ["status"], name: "index_tickets_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true
    t.decimal "available_hours", precision: 5, scale: 2, default: "8.0"
    t.string "avatar_color"
    t.string "avatar_initials"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", null: false
    t.string "jti", null: false
    t.string "last_name", null: false
    t.decimal "max_hours_per_ticket", precision: 5, scale: 2, default: "4.0"
    t.bigint "organization_id", null: false
    t.string "role", default: "user", null: false
    t.datetime "updated_at", null: false
    t.index ["email", "organization_id"], name: "index_users_on_email_and_organization_id", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "articles", "organizations"
  add_foreign_key "articles", "users", column: "author_id"
  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "categories", "organizations"
  add_foreign_key "holidays", "organizations"
  add_foreign_key "notifications", "tickets"
  add_foreign_key "notifications", "users"
  add_foreign_key "priorities", "organizations"
  add_foreign_key "queue_memberships", "queues"
  add_foreign_key "queue_memberships", "users"
  add_foreign_key "queues", "categories"
  add_foreign_key "queues", "organizations"
  add_foreign_key "scheduled_days", "tickets"
  add_foreign_key "scheduled_days", "users"
  add_foreign_key "ticket_attachments", "tickets"
  add_foreign_key "ticket_attachments", "users"
  add_foreign_key "ticket_comments", "tickets"
  add_foreign_key "ticket_comments", "users"
  add_foreign_key "ticket_histories", "tickets"
  add_foreign_key "ticket_histories", "users"
  add_foreign_key "tickets", "categories"
  add_foreign_key "tickets", "organizations"
  add_foreign_key "tickets", "priorities"
  add_foreign_key "tickets", "queues"
  add_foreign_key "tickets", "users", column: "assignee_id"
  add_foreign_key "tickets", "users", column: "requester_id"
  add_foreign_key "users", "organizations"
end
