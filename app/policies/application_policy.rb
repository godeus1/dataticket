class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "Usuário não autenticado" unless user

    @user   = user
    @record = record
  end

  # Defaults: apenas staff (admin/manager/analyst) tem acesso operacional básico
  def index?   = staff?
  def show?    = staff?
  def create?  = staff?
  def update?  = admin_or_manager?
  def destroy? = admin?

  protected

  # ── Helpers de hierarquia ─────────────────────────────────────────────────
  # admin    → tudo + exclusão + configurações de sistema
  # manager  → todos os tickets, triagem, status, sem config de sistema
  # analyst  → tickets atribuídos, comentários, esforço
  # user     → apenas tickets próprios

  # msp_admin é admin-equivalente DENTRO da empresa atualmente selecionada
  # (além de poder trocar de empresa e gerir contas). Por isso satisfaz todos
  # os checks operacionais de admin. A distinção de papel permanece estrita no
  # model (User#admin?) e no AccountPolicy (que checa user.msp_admin? à parte).
  def admin?
    user.role == "admin" || user.role == "msp_admin"
  end

  def manager?
    user.role == "manager"
  end

  def analyst?
    user.role == "analyst"
  end

  def regular_user?
    user.role == "user"
  end

  # admin + manager → pode triar, mudar status, ver todos os tickets
  def admin_or_manager?
    admin? || manager?
  end

  # admin + manager + analyst → equipe operacional
  def staff?
    admin? || manager? || analyst?
  end

  # Mantido para compatibilidade — agora inclui manager
  def admin_or_analyst?
    staff?
  end

  class Scope
    def initialize(user, scope)
      @user  = user
      @scope = scope
    end

    # Escopa pela empresa EFETIVA da requisição (Current.organization), não pela
    # organização-casa do usuário. Isso garante que o msp_admin que trocou de
    # empresa veja os dados da empresa correta — e, se o contexto não estiver
    # definido, escopa por nil (NOT NULL nas tabelas ⇒ resultado vazio = fail-closed).
    def resolve
      @scope.where(organization: Current.organization)
    end

    private

    attr_reader :user, :scope
  end
end
