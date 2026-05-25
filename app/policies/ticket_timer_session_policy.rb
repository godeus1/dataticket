class TicketTimerSessionPolicy < ApplicationPolicy
  # Qualquer membro da equipe que possa ver o ticket pode ver e registrar sessões
  def index?  = staff?
  def create? = staff?
end
