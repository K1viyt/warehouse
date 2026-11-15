class StockMovement < ApplicationRecord
  belongs_to :organization
  belongs_to :warehouse, class_name: "StockWarehouse"
  belongs_to :product
  belongs_to :user
  before_validation :assign_organization
  validate :same_organization
  validates :quantity, presence: true,
                        numericality: { greater_than: 0 }
  validates :movement_type, presence: true,
                            inclusion: { in: [ "receipt", "issue" ] }
  validates :reason, presence: true

  private

  def assign_organization
    self.organization ||= product&.organization
  end

  def same_organization
    { product: product, warehouse: warehouse, user: user }.each do |field, record|
      errors.add(field, "must belong to the same organization") if record && record.organization_id != organization_id
    end
  end
end
