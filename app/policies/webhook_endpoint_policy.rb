class WebhookEndpointPolicy < ApplicationPolicy
  def index?         = admin?
  def show?          = admin?
  def create?        = admin?
  def update?        = admin?
  def destroy?       = admin?
  def test_delivery? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: Current.organization)
    end
  end
end
