class UserPolicy < ApplicationPolicy
  # Manager precisa ver a lista de usuários para atribuir tickets
  def index?         = admin_or_manager?
  def show?          = admin_or_manager?

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
