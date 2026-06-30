class CreateSavedViews < ActiveRecord::Migration[8.1]
  def change
    # Listas salvas de filtros da tela de tickets — por USUÁRIO e por EMPRESA
    # (antes ficavam só no localStorage do navegador).
    create_table :saved_views do |t|
      t.references :user,         null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string  :name,    null: false
      t.jsonb   :filters, null: false, default: {}
      t.timestamps
    end
    add_index :saved_views, [:user_id, :organization_id]
  end
end
