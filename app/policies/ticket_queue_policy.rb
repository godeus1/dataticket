class TicketQueuePolicy < ApplicationPolicy
  # Todos os funcionários precisam ver as filas (triagem, atribuição)
  def index? = staff?
  def show?  = staff?

  # Gerenciar filas: somente admin
  def create?        = admin?
  def update?        = admin?
  def destroy?       = admin?
  def add_member?    = admin?
  def remove_member? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: @user.organization)
    end
  end
end
