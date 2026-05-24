class AddTrgmIndexToTickets < ActiveRecord::Migration[8.1]
  # Habilita pg_trgm para buscas por similaridade (ILIKE eficiente em grandes volumes).
  # O índice GIN cobre title e description — os dois campos usados em apply_search
  # em tickets_controller.rb.
  #
  # Sem este índice, ILIKE faz full table scan (Seq Scan).
  # Com ele, PostgreSQL usa o índice trigram → até 100x mais rápido em > 50k tickets.
  def up
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    add_index :tickets, :title,
              name:   "idx_tickets_title_trgm",
              using:  :gin,
              opclass: { title: :gin_trgm_ops }

    add_index :tickets, :description,
              name:   "idx_tickets_description_trgm",
              using:  :gin,
              opclass: { description: :gin_trgm_ops }
  end

  def down
    remove_index :tickets, name: "idx_tickets_title_trgm"       if index_exists?(:tickets, :title,       name: "idx_tickets_title_trgm")
    remove_index :tickets, name: "idx_tickets_description_trgm" if index_exists?(:tickets, :description, name: "idx_tickets_description_trgm")
  end
end
