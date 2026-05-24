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
        # Analyst sees:
        #   • Tickets atribuídos a eles, OU
        #   • Tickets não atribuídos que: não têm fila, ou têm fila à qual o analista pertence
        # Isso evita que analistas vejam tickets de filas onde não trabalham.
        analyst_queue_ids = @user.queue_ids
        if analyst_queue_ids.any?
          base.where(
            "assignee_id = :uid OR (assignee_id IS NULL AND (queue_id IS NULL OR queue_id IN (:qids)))",
            uid: @user.id, qids: analyst_queue_ids
          )
        else
          # Analista sem filas: vê apenas os próprios + não atribuídos sem fila
          base.where("assignee_id = ? OR (assignee_id IS NULL AND queue_id IS NULL)", @user.id)
        end
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
