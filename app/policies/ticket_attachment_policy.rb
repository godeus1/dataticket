class TicketAttachmentPolicy < ApplicationPolicy
  def index?    = true
  def show?     = true   # usado pelo download
  def create?   = true
  def destroy?  = admin? || record.user_id == user.id

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.all
    end
  end
end
