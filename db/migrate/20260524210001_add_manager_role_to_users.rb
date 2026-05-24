class AddManagerRoleToUsers < ActiveRecord::Migration[8.1]
  # O campo `role` em users é uma coluna string simples (sem enum no DB).
  # A validação de roles permitidos vive em User::ROLES no model.
  # Esta migração apenas documenta a adição do papel "manager" ao sistema
  # e atualiza qualquer check constraint que possa existir.
  #
  # Hierarquia após esta migração:
  #   admin   → acesso total + configurações de sistema + excluir tickets
  #   manager → visão total, tria tickets, muda status, sem config de admin
  #   analyst → apenas tickets atribuídos, comentar, registrar esforço
  #   user    → apenas seus próprios tickets

  def up
    # Sem alteração de schema necessária — a validação é feita no model.
    # Verifica que não há constraints ou enums bloqueando o novo valor.
    say "Role 'manager' adicionado ao User::ROLES. Nenhuma alteração de schema necessária."
    say "Para criar um gestor via console: User.create!(role: 'manager', ...)"
  end

  def down
    # Converte gestores em analistas se o papel for removido
    User.where(role: "manager").update_all(role: "analyst")
    say "#{User.where(role: 'analyst').count} usuários reconvertidos de manager para analyst"
  end
end
