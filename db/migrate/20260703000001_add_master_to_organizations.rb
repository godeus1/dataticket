class AddMasterToOrganizations < ActiveRecord::Migration[8.1]
  def up
    # Org MASTER da plataforma (Datatry): controla as demais empresas
    # (ativar/inativar, renomear, limites). Não pode ser inativada nem excluída.
    add_column :organizations, :master, :boolean, default: false, null: false

    execute <<~SQL
      UPDATE organizations SET master = true
      WHERE lower(name) = 'datatry' OR slug = 'datatry'
    SQL
  end

  def down
    remove_column :organizations, :master
  end
end
