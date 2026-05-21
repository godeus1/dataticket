class AddLegacyIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :legacy_id, :string
    add_index  :users, :legacy_id
  end
end
