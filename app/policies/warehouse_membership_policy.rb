class WarehouseMembershipPolicy < ApplicationPolicy
  def update?
    organization_admin? && !record.user.admin?
  end
end
