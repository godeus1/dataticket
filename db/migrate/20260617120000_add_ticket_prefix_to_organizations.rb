class AddTicketPrefixToOrganizations < ActiveRecord::Migration[8.1]
  # Prefixo de ticket por empresa (ex: SALV-0001, DTRY-0001).
  # Garante unicidade GLOBAL dos IDs de ticket entre empresas — prefixos
  # distintos impedem a colisão de chave primária que ocorreria com o antigo
  # formato TK-0001 compartilhado.
  def up
    add_column :organizations, :ticket_prefix, :string

    # Backfill: deriva o prefixo do slug (maiúsculo, alfanumérico, até 6 chars),
    # resolvendo colisões com sufixo numérico. Roda em SQL puro para não depender
    # das validações do model durante a migração.
    used = {}
    select_all("SELECT id, slug FROM organizations ORDER BY id").each do |row|
      base = row["slug"].to_s.gsub(/[^a-zA-Z0-9]/, "").upcase[0, 6]
      base = "ORG" if base.blank?
      base = "O#{base}"[0, 6] unless base.match?(/\A[A-Z]/)

      candidate = base
      i = 1
      while used[candidate]
        candidate = "#{base[0, 5]}#{i}"
        i += 1
      end
      used[candidate] = true

      execute(
        "UPDATE organizations SET ticket_prefix = #{quote(candidate)} WHERE id = #{row['id'].to_i}"
      )
    end

    change_column_null :organizations, :ticket_prefix, false
    add_index :organizations, :ticket_prefix, unique: true
  end

  def down
    remove_index  :organizations, :ticket_prefix
    remove_column :organizations, :ticket_prefix
  end
end
