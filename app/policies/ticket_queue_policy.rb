class TicketQueuePolicy < ApplicationPolicy
  # Todos que criam ticket podem LISTAR as filas — o Novo Ticket oferece a
  # fila como "Sub Categoria". Gerenciamento continua restrito.
  def index? = true
  def show?  = staff?

  # Gerenciar filas: somente admin
  def create?        = admin?
  def update?        = admin?
  def destroy?       = admin?
  def add_member?    = admin?
  def remove_member? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: Current.organization)
    end
  end
end
