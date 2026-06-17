class SlaPolicyPolicy < ApplicationPolicy
  # Manager pode ver políticas de SLA (visibilidade operacional)
  def index? = admin_or_manager?
  def show?  = admin_or_manager?

  # Criar/editar/excluir: somente admin
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: Current.organization)
    end
  end
end
