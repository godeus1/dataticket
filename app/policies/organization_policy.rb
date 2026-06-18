class OrganizationPolicy < ApplicationPolicy
  def show?   = true
  def update? = admin?

  # Listar empresas: qualquer autenticado (o controller escopa o que cada um vê).
  def index? = true

  # Criar empresa: somente msp_admin (super admin multi-empresa).
  def create? = user.msp_admin?
end
