class TicketAttachmentPolicy < ApplicationPolicy
  # Acesso ao ticket já é validado via policy_scope(Ticket) no controller
  def index?   = true
  def show?    = true   # download
  def create?  = true

  # Mover para a lixeira e restaurar: somente gestor (manager) e admin/msp_admin.
  def destroy? = admin_or_manager?
  def restore? = admin_or_manager?
  def trash?   = admin_or_manager?

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.all
    end
  end
end
