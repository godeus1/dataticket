class ReportPolicy < ApplicationPolicy
  def index? = admin_or_analyst?
end
