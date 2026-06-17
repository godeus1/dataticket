class AuditLogPolicy < ApplicationPolicy
  def index? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(organization: Current.organization)
    end
  end
end
