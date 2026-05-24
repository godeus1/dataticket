class ReportPolicy < ApplicationPolicy
  # Relatórios disponíveis para admin, manager e analyst
  def index?  = staff?
  def export? = staff?
end
