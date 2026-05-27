class CleanOrphanedScheduledDays < ActiveRecord::Migration[8.0]
  # Remove ScheduledDays futuros para tickets já Resolvidos ou Fechados.
  # Estes resíduos ficaram porque o release_capacity! não existia antes do Sprint 1.
  def up
    execute <<~SQL
      DELETE FROM scheduled_days
      WHERE date >= CURRENT_DATE
        AND ticket_id IN (
          SELECT id FROM tickets
          WHERE status IN ('Resolvido', 'Fechado')
             OR deleted_at IS NOT NULL
        )
    SQL

    # Remove também ScheduledDays de tickets cujo effort_used >= effort_estimated
    # (esforço totalmente consumido, sem trabalho futuro necessário).
    execute <<~SQL
      DELETE FROM scheduled_days
      WHERE date >= CURRENT_DATE
        AND ticket_id IN (
          SELECT id FROM tickets
          WHERE effort_estimated > 0
            AND effort_used >= effort_estimated
            AND status NOT IN ('Resolvido', 'Fechado')
            AND deleted_at IS NULL
        )
    SQL
  end

  def down
    # Não é possível reverter limpeza de dados; irreversível por design.
    raise ActiveRecord::IrreversibleMigration
  end
end
