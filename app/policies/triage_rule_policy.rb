class TriageRulePolicy < ApplicationPolicy
  def index?   = admin_or_analyst?
  def show?    = admin_or_analyst?
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: @user.organization)
    end
  end
end
