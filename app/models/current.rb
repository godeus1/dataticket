# Armazena o usuário que está realizando a ação na requisição atual.
# Usado para rastrear o actor em callbacks de model (ex: TicketHistory).
class Current < ActiveSupport::CurrentAttributes
  attribute :user
end
