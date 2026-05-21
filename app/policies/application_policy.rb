class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "Usuário não autenticado" unless user

    @user   = user
    @record = record
  end

  def index?   = admin_or_analyst?
  def show?    = admin_or_analyst?
  def create?  = admin_or_analyst?
  def update?  = admin?
  def destroy? = admin?

  protected

  def admin?
    user.role == "admin"
  end

  def analyst?
    user.role == "analyst"
  end

  def admin_or_analyst?
    admin? || analyst?
  end

  class Scope
    def initialize(user, scope)
      @user  = user
      @scope = scope
    end

    def resolve
      @scope.where(organization: @user.organization)
    end

    private

    attr_reader :user, :scope
  end
end
