class AccountPolicy < ApplicationPolicy
  # Only msp_admin users can manage accounts
  def index?         = user.msp_admin?
  def show?          = user.msp_admin?
  def create?        = user.msp_admin?
  def update?        = user.msp_admin?
  def destroy?       = user.msp_admin?
  def organizations? = user.msp_admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.msp_admin?
        account = user.organization.account
        account ? Account.where(id: account.id) : Account.none
      else
        Account.none
      end
    end
  end
end
