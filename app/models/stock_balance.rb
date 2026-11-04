class StockBalance < ApplicationRecord
  belongs_to :organization
  belongs_to :warehouse, class_name: "StockWarehouse"
  belongs_to :product
  before_validation :assign_organization
  validates :product_id, uniqueness: { scope: :warehouse_id }
  validate :same_organization
  validates :quantity, presence: true,
                       numericality: { greater_than_or_equal_to: 0 }

  private

  def assign_organization
    self.organization ||= product&.organization
  end

  def same_organization
    errors.add(:product, "must belong to the same organization") if product && product.organization_id != organization_id
    errors.add(:warehouse, "must belong to the same organization") if warehouse && warehouse.organization_id != organization_id
  end
end
