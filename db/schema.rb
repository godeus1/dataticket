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

ActiveRecord::Schema[8.1].define(version: 2026_06_17_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "accounts", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "plan", default: "standard", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_accounts_on_slug", unique: true
  end

  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message_checksum", null: false
    t.string "message_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "articles", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.text "body"
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

  create_table "custom_fields", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "field_type", default: "text", null: false
    t.string "name", null: false
    t.jsonb "options", default: [], null: false
    t.bigint "organization_id", null: false
    t.integer "position", default: 0, null: false
    t.boolean "required", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "position"], name: "index_custom_fields_on_organization_id_and_position"
    t.index ["organization_id"], name: "index_custom_fields_on_organization_id"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "aggregate_id", null: false
    t.string "aggregate_type", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.datetime "occurred_at", null: false
    t.bigint "organization_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["actor_id"], name: "index_events_on_actor_id"
    t.index ["aggregate_type", "aggregate_id"], name: "index_events_on_aggregate_type_and_aggregate_id"
    t.index ["occurred_at"], name: "index_events_on_occurred_at"
    t.index ["organization_id", "event_type"], name: "index_events_on_organization_id_and_event_type"
    t.index ["organization_id"], name: "index_events_on_organization_id"
  end

  create_table "holidays", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "kind", default: "Nacional"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.boolean "recurring", default: false, null: false
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
    t.index ["ticket_id"], name: "index_notifications_on_ticket_id"
    t.index ["user_id", "read", "created_at"], name: "idx_notifications_user_read_created"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.bigint "account_id"
    t.datetime "created_at", null: false
    t.string "date_format", default: "DD/MM/YYYY"
    t.boolean "emails_enabled", default: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "smtp_host"
    t.text "smtp_pass"
    t.integer "smtp_port", default: 587
    t.string "smtp_user"
    t.string "ticket_prefix", null: false
    t.string "timezone", default: "America/Sao_Paulo"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_organizations_on_account_id"
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
    t.index ["ticket_prefix"], name: "index_organizations_on_ticket_prefix", unique: true
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
    t.string "description"
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
    t.index ["ticket_id", "user_id", "date"], name: "idx_scheduled_days_unique_ticket_user_date", unique: true
    t.index ["user_id", "date"], name: "idx_scheduled_days_user_date"
    t.index ["user_id"], name: "index_scheduled_days_on_user_id"
  end

  create_table "sla_policies", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.bigint "priority_id"
    t.integer "resolve_hours", null: false
    t.integer "response_hours", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_sla_policies_on_category_id"
    t.index ["organization_id", "priority_id", "category_id"], name: "idx_sla_policies_org_priority_category", unique: true
    t.index ["organization_id"], name: "index_sla_policies_on_organization_id"
    t.index ["priority_id"], name: "index_sla_policies_on_priority_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "sso_configurations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "idp_cert", null: false
    t.string "idp_entity_id", null: false
    t.string "idp_sso_url", null: false
    t.string "name_id_format", default: "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
    t.bigint "organization_id", null: false
    t.string "sp_entity_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_sso_configurations_on_organization_id", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.string "color", default: "#6b7280", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_tags_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_tags_on_organization_id"
  end

  create_table "ticket_assignees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ticket_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ticket_id", "user_id"], name: "index_ticket_assignees_on_ticket_id_and_user_id", unique: true
    t.index ["ticket_id"], name: "index_ticket_assignees_on_ticket_id"
    t.index ["user_id"], name: "index_ticket_assignees_on_user_id"
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
    t.index ["ticket_id"], name: "index_ticket_attachments_on_ticket_id"
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

  create_table "ticket_counters", id: false, force: :cascade do |t|
    t.integer "counter", default: 0, null: false
    t.bigint "organization_id", null: false
    t.index ["organization_id"], name: "index_ticket_counters_on_organization_id", unique: true
  end

  create_table "ticket_field_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "custom_field_id", null: false
    t.string "ticket_id", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["custom_field_id"], name: "index_ticket_field_values_on_custom_field_id"
    t.index ["ticket_id", "custom_field_id"], name: "index_ticket_field_values_on_ticket_id_and_custom_field_id", unique: true
  end

  create_table "ticket_histories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "field"
    t.string "from_value"
    t.string "ticket_id", null: false
    t.string "to_value"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ticket_id", "created_at"], name: "idx_ticket_histories_ticket_created"
    t.index ["ticket_id"], name: "index_ticket_histories_on_ticket_id"
    t.index ["user_id"], name: "index_ticket_histories_on_user_id"
  end

  create_table "ticket_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "tag_id", null: false
    t.string "ticket_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_ticket_tags_on_tag_id"
    t.index ["ticket_id", "tag_id"], name: "index_ticket_tags_on_ticket_id_and_tag_id", unique: true
  end

  create_table "ticket_timer_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "duration_mins", default: 0.0
    t.datetime "started_at", null: false
    t.string "status", default: "completed", null: false
    t.datetime "stopped_at"
    t.string "ticket_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ticket_id", "started_at"], name: "index_ticket_timer_sessions_on_ticket_id_and_started_at"
    t.index ["ticket_id"], name: "index_ticket_timer_sessions_on_ticket_id"
    t.index ["user_id", "status"], name: "idx_timer_sessions_user_status"
    t.index ["user_id"], name: "index_ticket_timer_sessions_on_user_id"
  end

  create_table "tickets", id: :string, force: :cascade do |t|
    t.bigint "assignee_id"
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.text "csat_comment"
    t.integer "csat_score"
    t.datetime "csat_sent_at"
    t.string "csat_token"
    t.datetime "deadline"
    t.datetime "deleted_at"
    t.integer "deleted_by_id"
    t.text "description"
    t.decimal "effort_estimated", precision: 6, scale: 2, default: "0.0"
    t.decimal "effort_used", precision: 6, scale: 2, default: "0.0"
    t.boolean "escalated", default: false, null: false
    t.datetime "escalated_at"
    t.bigint "organization_id", null: false
    t.bigint "priority_id"
    t.bigint "queue_id"
    t.bigint "requester_id", null: false
    t.datetime "resolved_at"
    t.string "status", default: "Não iniciado", null: false
    t.string "ticket_type", default: "incidente", null: false
    t.string "title", null: false
    t.boolean "triaged", default: false
    t.datetime "triaged_at"
    t.datetime "updated_at", null: false
    t.index ["assignee_id", "status", "deleted_at"], name: "idx_tickets_assignee_status_deleted"
    t.index ["assignee_id", "status"], name: "index_tickets_on_assignee_id_and_status"
    t.index ["category_id"], name: "index_tickets_on_category_id"
    t.index ["created_at"], name: "index_tickets_on_created_at"
    t.index ["csat_token"], name: "index_tickets_on_csat_token", unique: true
    t.index ["deadline"], name: "index_tickets_on_deadline"
    t.index ["deleted_at"], name: "index_tickets_on_deleted_at"
    t.index ["description"], name: "idx_tickets_description_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["organization_id", "deadline", "deleted_at"], name: "idx_tickets_org_deadline_deleted"
    t.index ["organization_id", "status", "deleted_at"], name: "idx_tickets_org_status_deleted"
    t.index ["organization_id", "status"], name: "index_tickets_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_tickets_on_organization_id"
    t.index ["priority_id"], name: "index_tickets_on_priority_id"
    t.index ["queue_id"], name: "index_tickets_on_queue_id"
    t.index ["requester_id"], name: "index_tickets_on_requester_id"
    t.index ["status"], name: "index_tickets_on_status"
    t.index ["ticket_type"], name: "index_tickets_on_ticket_type"
    t.index ["title"], name: "idx_tickets_title_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "triage_rules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.string "keyword", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.integer "position", default: 0, null: false
    t.bigint "priority_id"
    t.bigint "queue_id"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_triage_rules_on_category_id"
    t.index ["organization_id", "position"], name: "index_triage_rules_on_organization_id_and_position"
    t.index ["organization_id"], name: "index_triage_rules_on_organization_id"
    t.index ["priority_id"], name: "index_triage_rules_on_priority_id"
    t.index ["queue_id"], name: "index_triage_rules_on_queue_id"
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
    t.string "legacy_id"
    t.decimal "max_hours_per_ticket", precision: 5, scale: 2, default: "4.0"
    t.bigint "organization_id", null: false
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "user", null: false
    t.datetime "updated_at", null: false
    t.index ["email", "organization_id"], name: "index_users_on_email_and_organization_id", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["legacy_id"], name: "index_users_on_legacy_id"
    t.index ["organization_id", "active", "role"], name: "idx_users_org_active_role"
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token"
  end

  create_table "webhook_endpoints", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "events", default: [], array: true
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "secret"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["organization_id"], name: "index_webhook_endpoints_on_organization_id"
  end

  add_foreign_key "articles", "organizations"
  add_foreign_key "articles", "users", column: "author_id"
  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "categories", "organizations"
  add_foreign_key "custom_fields", "organizations"
  add_foreign_key "events", "organizations"
  add_foreign_key "events", "users", column: "actor_id"
  add_foreign_key "holidays", "organizations"
  add_foreign_key "notifications", "tickets"
  add_foreign_key "notifications", "users"
  add_foreign_key "organizations", "accounts"
  add_foreign_key "priorities", "organizations"
  add_foreign_key "queue_memberships", "queues"
  add_foreign_key "queue_memberships", "users"
  add_foreign_key "queues", "categories"
  add_foreign_key "queues", "organizations"
  add_foreign_key "scheduled_days", "tickets"
  add_foreign_key "scheduled_days", "users"
  add_foreign_key "sla_policies", "categories"
  add_foreign_key "sla_policies", "organizations"
  add_foreign_key "sla_policies", "priorities"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "sso_configurations", "organizations"
  add_foreign_key "tags", "organizations"
  add_foreign_key "ticket_assignees", "tickets"
  add_foreign_key "ticket_assignees", "users"
  add_foreign_key "ticket_attachments", "tickets"
  add_foreign_key "ticket_attachments", "users"
  add_foreign_key "ticket_comments", "tickets"
  add_foreign_key "ticket_comments", "users"
  add_foreign_key "ticket_counters", "organizations"
  add_foreign_key "ticket_field_values", "custom_fields"
  add_foreign_key "ticket_field_values", "tickets"
  add_foreign_key "ticket_histories", "tickets"
  add_foreign_key "ticket_histories", "users"
  add_foreign_key "ticket_tags", "tags"
  add_foreign_key "ticket_tags", "tickets"
  add_foreign_key "ticket_timer_sessions", "tickets"
  add_foreign_key "ticket_timer_sessions", "users"
  add_foreign_key "tickets", "categories"
  add_foreign_key "tickets", "organizations"
  add_foreign_key "tickets", "priorities"
  add_foreign_key "tickets", "queues"
  add_foreign_key "tickets", "users", column: "assignee_id"
  add_foreign_key "tickets", "users", column: "deleted_by_id"
  add_foreign_key "tickets", "users", column: "requester_id"
  add_foreign_key "triage_rules", "categories"
  add_foreign_key "triage_rules", "organizations"
  add_foreign_key "triage_rules", "priorities"
  add_foreign_key "triage_rules", "queues"
  add_foreign_key "users", "organizations"
  add_foreign_key "webhook_endpoints", "organizations"
end
