class AddPerformanceIndices < ActiveRecord::Migration[8.1]
  # CONCURRENTLY não pode rodar dentro de transação — esta diretiva desabilita
  # o wrap de transação automático do Rails para esta migration.
  # O índice é criado em background: leituras e escritas continuam sem lock.
  disable_ddl_transaction!

  def change
    # ── tickets ────────────────────────────────────────────────────────────────
    # Scope :active usa deleted_at: nil em toda listagem — índice composto elimina
    # o Seq Scan em tabelas com muitos tickets deletados.
    add_index :tickets, %i[organization_id status deleted_at],
              name:         "idx_tickets_org_status_deleted",
              algorithm:    :concurrently,
              if_not_exists: true

    # Filtro de responsável + status (relatórios, agenda, realocação)
    add_index :tickets, %i[assignee_id status deleted_at],
              name:         "idx_tickets_assignee_status_deleted",
              algorithm:    :concurrently,
              if_not_exists: true

    # SlaDigestJob + scope :overdue combinam deadline + status + deleted_at
    add_index :tickets, %i[organization_id deadline deleted_at],
              name:         "idx_tickets_org_deadline_deleted",
              algorithm:    :concurrently,
              if_not_exists: true

    # ── scheduled_days ────────────────────────────────────────────────────────
    # UserCapacityService filtra por (user_id, date range) — índice standalone
    # user_id existe mas sem date, forçando filter step extra.
    add_index :scheduled_days, %i[user_id date],
              name:         "idx_scheduled_days_user_date",
              algorithm:    :concurrently,
              if_not_exists: true

    # ── ticket_histories ──────────────────────────────────────────────────────
    # scope :recent usa order(created_at: :desc) dentro do ticket — o índice
    # em ticket_id existe mas sem created_at, exigindo sort.
    add_index :ticket_histories, %i[ticket_id created_at],
              name:         "idx_ticket_histories_ticket_created",
              algorithm:    :concurrently,
              if_not_exists: true

    # ── users ─────────────────────────────────────────────────────────────────
    # SlaDigestJob, EscalationJob e policy_scope filtram users por org + active + role
    add_index :users, %i[organization_id active role],
              name:         "idx_users_org_active_role",
              algorithm:    :concurrently,
              if_not_exists: true

    # ── notifications ─────────────────────────────────────────────────────────
    # scope :recent usa order(created_at: :desc) — índice (user_id, read) existe
    # mas não cobre ordenação por created_at.
    add_index :notifications, %i[user_id read created_at],
              name:         "idx_notifications_user_read_created",
              algorithm:    :concurrently,
              if_not_exists: true
  end
end
