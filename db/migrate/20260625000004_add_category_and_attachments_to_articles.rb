class AddCategoryAndAttachmentsToArticles < ActiveRecord::Migration[8.1]
  def change
    add_reference :articles, :category, foreign_key: true, null: true

    create_table :article_attachments do |t|
      t.references :article, null: false, foreign_key: true
      t.references :user,    null: false, foreign_key: true
      t.string  :filename,     null: false
      t.string  :content_type
      t.integer :byte_size
      t.string  :storage_key
      t.timestamps
    end
  end
end
