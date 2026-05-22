class TagPolicy < ApplicationPolicy
  def index?   = true            # todos os usuários autenticados podem ver tags
  def show?    = true
  def create?  = admin_or_analyst?
  def update?  = admin_or_analyst?
  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: @user.organization)
    end
  end
end
