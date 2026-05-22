class NotificationPolicy < ApplicationPolicy
  def index?        = true
  def update?       = record == :notification || record.user_id == user.id
  def mark_all_read? = true

  class Scope < ApplicationPolicy::Scope
    def resolve
      @scope.where(user: @user)
    end
  end
end
