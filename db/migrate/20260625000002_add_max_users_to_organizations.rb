class AddMaxUsersToOrganizations < ActiveRecord::Migration[8.1]
  def change
    # Limite de usuários por organização. nil = ilimitado.
    add_column :organizations, :max_users, :integer
  end
end
