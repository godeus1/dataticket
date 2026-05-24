class TicketCommentPolicy < ApplicationPolicy
  # Quem pode comentar = quem tem acesso ao ticket (já validado via policy_scope no controller)
  def index?   = true
  def create?  = true

  # Pode apagar: admin ou o próprio autor
  def destroy? = admin? || record.user_id == user.id

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.all
    end
  end
end
