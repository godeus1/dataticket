class ArticlePolicy < ApplicationPolicy
  def index?   = true
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
