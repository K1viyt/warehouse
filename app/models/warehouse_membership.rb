class WarehouseMembership < ApplicationRecord
  belongs_to :organization
  belongs_to :warehouse, class_name: "StockWarehouse"
  belongs_to :user

  enum :role, { operator: "operator", warehouse_manager: "warehouse_manager" }, validate: true
  enum :status, { pending: "pending", active: "active", blocked: "blocked" }, validate: true

  validates :user_id, uniqueness: { scope: :warehouse_id }
  validate :same_organization

  private

  def same_organization
    errors.add(:warehouse, "must belong to the same organization") if warehouse && warehouse.organization_id != organization_id
    errors.add(:user, "must belong to the same organization") if user && user.organization_id != organization_id
  end
end
