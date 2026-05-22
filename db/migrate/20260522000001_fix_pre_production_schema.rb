class FixPreProductionSchema < ActiveRecord::Migration[8.1]
  def change
    # ── holidays: adicionar campo recurring ────────────────────────────────────
    add_column :holidays, :recurring, :boolean, default: false, null: false

    # ── queues: adicionar campo description ────────────────────────────────────
    add_column :queues, :description, :string

    # ── articles: renomear content → body (padrão usado no controller) ─────────
    rename_column :articles, :content, :body

    # ── tickets: índice em requester_id (TicketPolicy::Scope filtra por isso) ──
    add_index :tickets, :requester_id

    # ── ticket_attachments: índice em ticket_id ────────────────────────────────
    add_index :ticket_attachments, :ticket_id

    # ── notifications: índice em ticket_id ────────────────────────────────────
    add_index :notifications, :ticket_id
  end
end
