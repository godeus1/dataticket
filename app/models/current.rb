# Armazena o contexto da requisição atual (resetado automaticamente pelo Rails
# ao final de cada request).
#   :user         → actor que realiza a ação (rastreio em callbacks, ex: TicketHistory)
#   :organization → empresa EFETIVA da requisição (respeita a troca de org do msp_admin
#                   via header X-Organization-Id). É a ÚNICA fonte de verdade de tenancy:
#                   tanto controllers quanto Pundit Scopes devem escopar por ela.
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :organization
end
