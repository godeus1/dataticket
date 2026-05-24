class TriageRulePolicy < ApplicationPolicy
  # Manager pode ver regras de triagem (para entender o fluxo)
  def index? = admin_or_manager?
  def show?  = admin_or_manager?

  # Criar/editar/excluir regras: somente admin
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: @user.organization)
    end
  end
end
