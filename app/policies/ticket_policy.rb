class TicketPolicy < ApplicationPolicy
  # Qualquer autenticado pode abrir ticket; escopo controla visibilidade
  def index?   = true
  def show?    = can_access_ticket?
  def create?  = true

  # Admin/Manager: edita tudo. Analyst: só campos de esforço (controlado no controller).
  def update?  = can_access_ticket? && (admin_or_manager? || analyst?)

  # Somente admin pode mover para lixeira / excluir permanentemente
  def destroy?          = admin?
  def restore?          = admin?
  def purge?            = admin?
  def trash_index?      = admin?

  # Triagem, mudança de status e atribuição: admin e manager apenas
  # Exceção: analista pode fechar um ticket quando o esforço estimado foi totalmente consumido
  def triage?        = admin_or_manager?
  def change_status?
    return true if admin_or_manager?
    # Analista pode somente fechar quando esforço >= estimado e é responsável
    analyst? && can_access_ticket? && closes_with_full_effort?
  end
  def assign?        = admin_or_manager?
  def bulk_triage?   = admin_or_manager?

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = @scope.active.where(organization: @user.organization)

      case @user.role
      when "admin", "manager"
        base
      when "analyst"
        # Analista vê tickets onde é assignee principal OU co-responsável
        base.where(
          "tickets.assignee_id = :uid OR tickets.id IN (SELECT ticket_id FROM ticket_assignees WHERE user_id = :uid)",
          uid: @user.id
        )
      else
        base.where(requester_id: @user.id)
      end
    end
  end

  private

  def can_access_ticket?
    case user.role
    when "admin", "manager"
      true
    when "analyst"
      record.assignee_id == user.id ||
        record.ticket_assignees.exists?(user_id: user.id)
    else
      record.requester_id == user.id
    end
  end

  # Verdadeiro quando o esforço estimado é > 0 e o utilizado já atingiu ou superou
  def closes_with_full_effort?
    est = record.effort_estimated.to_f
    est > 0 && record.effort_used.to_f >= est
  end
end
