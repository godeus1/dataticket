class SsoConfigurationPolicy < ApplicationPolicy
  def show?    = admin?
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: Current.organization)
    end
  end
end
