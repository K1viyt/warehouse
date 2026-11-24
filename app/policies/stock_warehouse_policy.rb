class StockWarehousePolicy < ApplicationPolicy
  def update?
    organization_admin?
  end
  alias_method :create?, :update?

  def operate?
    return false unless user&.active? && !user.password_change_required? && user.organization_id == record.organization_id
    user.admin? || user.warehouse_memberships.active.exists?(warehouse_id: record.id)
  end

  def manage?
    organization_admin? || (operate? && user.warehouse_memberships.active.warehouse_manager.exists?(warehouse_id: record.id))
  end
end
