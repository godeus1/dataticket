class ArticlePolicy < ApplicationPolicy
  # Base de conhecimento: todos podem ler
  def index? = true
  def show?  = true

  # Criar e editar artigos: equipe operacional (admin, manager, analyst)
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
