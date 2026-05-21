class TicketPolicy < ApplicationPolicy
  def index?         = true  # scope handles visibility
  def show?          = owner_or_staff?
  def create?        = true  # any authenticated user can open a ticket
  def update?        = admin_or_analyst?
  def destroy?       = admin?
  def triage?        = admin_or_analyst?
  def change_status? = admin_or_analyst?
  def assign?        = admin_or_analyst?

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = @scope.where(organization: @user.organization)

      case @user.role
      when "admin"
        base
      when "analyst"
        # Analyst sees tickets assigned to them or unassigned
        base.where("assignee_id = ? OR assignee_id IS NULL", @user.id)
      else
        # Regular user sees only their own tickets
        base.where(requester_id: @user.id)
      end
    end
  end

  private

  def owner_or_staff?
    admin_or_analyst? || record.requester_id == user.id
  end
end
