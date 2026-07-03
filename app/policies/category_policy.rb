class CategoryPolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  def create?  = admin?
  def update?  = admin?
  # Excluir categoria: somente SUPER ADMIN (e o controller ainda exige que a
  # categoria não tenha nenhum ticket na organização).
  def destroy? = user.role == "msp_admin"

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: Current.organization)
    end
  end
end
