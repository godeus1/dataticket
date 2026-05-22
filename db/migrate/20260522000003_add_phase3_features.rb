class AddPhase3Features < ActiveRecord::Migration[8.1]
  def change
    # ── Ticket type (incidente / problema / mudanca / requisicao) ──────────────
    add_column :tickets, :ticket_type, :string, default: "incidente", null: false
    add_index  :tickets, :ticket_type

    # ── CSAT (Customer Satisfaction) ─────────────────────────────────────────
    add_column :tickets, :csat_score,   :integer   # 1–5
    add_column :tickets, :csat_comment, :text
    add_column :tickets, :csat_token,   :string    # token de URL para avaliação anônima
    add_column :tickets, :csat_sent_at, :datetime
    add_index  :tickets, :csat_token, unique: true

    # ── Escalation flag ────────────────────────────────────────────────────────
    add_column :tickets, :escalated,    :boolean, default: false, null: false
    add_column :tickets, :escalated_at, :datetime
  end
end
