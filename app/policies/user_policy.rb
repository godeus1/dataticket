class UserPolicy < ApplicationPolicy
  # Analyst precisa ver usuários para exibir nomes de solicitante/responsável em tickets
  def index?         = staff?
  def show?          = staff?
  def capacity?      = staff?  # carga de trabalho visível a toda a equipe

  # Criação, edição e exclusão de usuários: somente admin
  def create?        = admin?
  def update?        = admin?
  def destroy?       = admin?
  def toggle_active? = admin?
  def reset_password? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: @user.organization)
    end
  end
end
