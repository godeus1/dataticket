class TicketAttachmentPolicy < ApplicationPolicy
  # Acesso ao ticket já é validado via policy_scope(Ticket) no controller
  def index?   = true
  def show?    = true   # download
  def create?  = true

  # Pode apagar: admin, manager ou o próprio autor
  def destroy? = admin_or_manager? || record.user_id == user.id

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.all
    end
  end
end
