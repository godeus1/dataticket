class CustomFieldPolicy < ApplicationPolicy
  # Campos customizados: equipe operacional pode ver (para preencher em tickets)
  def index? = staff?
  def show?  = staff?

  # Gerenciar campos: somente admin
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: @user.organization)
    end
  end
end
