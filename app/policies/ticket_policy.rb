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

  # Triagem e atribuição: admin e manager apenas
  # Mudança de status: admin, manager e analista (analista restrito aos seus tickets via can_access_ticket?)
  def triage?        = admin_or_manager?
  def change_status?
    return true if admin_or_manager?
    analyst? && can_access_ticket?
  end
  def assign?        = admin_or_manager?
  def bulk_triage?   = admin_or_manager?

  # "+ Horas": adicionar esforço — SuperAdmin, admin, gestor e analista
  # (analista restrito aos seus tickets via can_access_ticket?).
  def add_effort?    = can_access_ticket? && (admin_or_manager? || analyst?)
  # Apagar uma adição de esforço: somente SuperAdmin.
  def remove_effort? = user.role == "msp_admin"

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = @scope.active.where(organization: Current.organization)

      case @user.role
      when "admin", "manager", "msp_admin"
        base
      when "analyst"
        # Analista vê tickets onde é assignee principal OU co-responsável, E
        # também tickets NÃO TRIADOS das filas em que é membro (a fila inteira
        # enxerga o ticket até a triagem; depois, só o responsável/co).
        base.where(
          "tickets.assignee_id = :uid
           OR tickets.id IN (SELECT ticket_id FROM ticket_assignees WHERE user_id = :uid)
           OR (tickets.triaged = false AND tickets.queue_id IN (SELECT queue_id FROM queue_memberships WHERE user_id = :uid))",
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
    when "admin", "manager", "msp_admin"
      true
    when "analyst"
      record.assignee_id == user.id ||
        record.ticket_assignees.exists?(user_id: user.id) ||
        (!record.triaged && record.queue_id.present? &&
          QueueMembership.exists?(queue_id: record.queue_id, user_id: user.id))
    else
      record.requester_id == user.id
    end
  end


end
