class EventPolicy < ApplicationPolicy
  def index? = admin_or_analyst?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: Current.organization)
    end
  end
end
