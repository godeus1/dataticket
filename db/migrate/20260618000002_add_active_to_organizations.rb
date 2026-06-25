class AddActiveToOrganizations < ActiveRecord::Migration[8.1]
  # Empresas podem ser INATIVADAS (nunca deletadas). Empresa inativa bloqueia o
  # login dos seus usuários.
  def change
    add_column :organizations, :active, :boolean, default: true, null: false
  end
end
