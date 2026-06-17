class AddTicketPrefixToOrganizations < ActiveRecord::Migration[8.1]
  # Prefixo de ticket por empresa (ex: SALV-0001, DTRY-0001).
  # Garante unicidade GLOBAL dos IDs de ticket entre empresas — prefixos
  # distintos impedem a colisão de chave primária que ocorreria com o antigo
  # formato TK-0001 compartilhado.
  def up
    add_column :organizations, :ticket_prefix, :string

    # Backfill do prefixo, em SQL puro (não depende das validações do model):
    #   1. Se a empresa JÁ tem tickets, preserva o prefixo deles (ex: Salvabras = "TK")
    #      — evita o formato duplo (TK-xxxx antigos + SLUG-xxxx novos).
    #   2. Caso contrário, deriva do slug (maiúsculo, alfanumérico, até 6 chars).
    # Colisões são resolvidas com sufixo numérico + índice único garante integridade.
    used = {}
    select_all("SELECT id, slug FROM organizations ORDER BY id").each do |row|
      org_id = row["id"].to_i

      existing_ticket_id = select_value(
        "SELECT id FROM tickets WHERE organization_id = #{org_id} ORDER BY created_at ASC LIMIT 1"
      )

      base =
        if existing_ticket_id.to_s =~ /\A([A-Za-z][A-Za-z0-9]*)-\d+\z/
          # Preserva o prefixo dos tickets existentes (continuidade)
          Regexp.last_match(1).upcase[0, 10]
        else
          b = row["slug"].to_s.gsub(/[^a-zA-Z0-9]/, "").upcase[0, 6]
          b = "ORG" if b.blank?
          b = "O#{b}"[0, 6] unless b.match?(/\A[A-Z]/)
          b
        end

      candidate = base
      i = 1
      while used[candidate]
        candidate = "#{base[0, 5]}#{i}"
        i += 1
      end
      used[candidate] = true

      execute(
        "UPDATE organizations SET ticket_prefix = #{quote(candidate)} WHERE id = #{org_id}"
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
