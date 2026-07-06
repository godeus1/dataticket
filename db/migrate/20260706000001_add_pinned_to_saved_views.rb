class AddPinnedToSavedViews < ActiveRecord::Migration[8.1]
  def change
    # Lista FIXADA: aplicada automaticamente ao abrir a tela de tickets.
    # Apenas uma por usuário+empresa (garantido no controller).
    add_column :saved_views, :pinned, :boolean, default: false, null: false
  end
end
