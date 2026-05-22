class OrganizationPolicy < ApplicationPolicy
  def show?   = true
  def update? = admin?
end
