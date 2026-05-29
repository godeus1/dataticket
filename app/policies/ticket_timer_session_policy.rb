class TicketTimerSessionPolicy < ApplicationPolicy
  # Qualquer membro da equipe que possa ver o ticket pode ver e registrar sessões
  def index?  = staff?
  def create? = staff?
  def start?  = staff?
  def stop?   = staff?
  def update? = staff?
end
