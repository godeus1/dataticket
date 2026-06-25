class AddAuthorFieldsToTicketComments < ActiveRecord::Migration[8.1]
  def change
    # Comentários originados de respostas de e-mail podem não ter um usuário do
    # DataTicket vinculado (remetente desconhecido). Nesses casos guardamos o
    # nome/e-mail do autor diretamente no comentário.
    change_column_null :ticket_comments, :user_id, true
    add_column :ticket_comments, :author_name,  :string
    add_column :ticket_comments, :author_email, :string
    add_column :ticket_comments, :source,       :string, default: "app", null: false
  end
end
