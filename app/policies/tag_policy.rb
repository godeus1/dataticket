class TagPolicy < ApplicationPolicy
  # Tags visíveis para todos (necessário ao criar tickets)
  def index? = true
  def show?  = true

  # Criar e editar tags: equipe operacional
  def create?  = staff?
  def update?  = staff?

  # Excluir: somente admin
  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: @user.organization)
    end
  end
end
