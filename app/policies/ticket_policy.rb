class TicketPolicy < ApplicationPolicy
  # Qualquer autenticado pode abrir ticket; escopo controla visibilidade
  def index?   = true
  def show?    = can_access_ticket?
  def create?  = true

  # Admin/Manager: edita tudo. Analyst: só campos de esforço (controlado no controller).
  def update?  = can_access_ticket? && (admin_or_manager? || analyst?)

  # Somente admin pode excluir tickets
  def destroy? = admin?

  # Triagem, mudança de status e atribuição: admin e manager apenas
  def triage?        = admin_or_manager?
  def change_status? = admin_or_manager?
  def assign?        = admin_or_manager?
  def bulk_triage?   = admin_or_manager?

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = @scope.where(organization: @user.organization)

      case @user.role
      when "admin", "manager"
        # Admin e Gestor veem TODOS os tickets da organização
        base

      when "analyst"
        # Analista vê APENAS tickets atribuídos a ele.
        # Tickets sem triagem (não atribuídos) são invisíveis para analistas.
        base.where(assignee_id: @user.id)

      else
        # Usuário comum vê apenas os tickets que ele criou
        base.where(requester_id: @user.id)
      end
    end
  end

  private

  # Verifica se o usuário tem acesso ao ticket específico
  def can_access_ticket?
    case user.role
    when "admin", "manager"
      true
    when "analyst"
      record.assignee_id == user.id
    else
      record.requester_id == user.id
    end
  end
end
