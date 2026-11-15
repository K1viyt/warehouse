# Warehouse is already the application's top-level module (config/application.rb).
class StockWarehouse < ApplicationRecord
  self.table_name = "warehouses"

  belongs_to :organization
  has_many :warehouse_memberships, foreign_key: :warehouse_id, dependent: :restrict_with_error
  has_many :stock_balances, foreign_key: :warehouse_id, dependent: :restrict_with_error
  has_many :stock_movements, foreign_key: :warehouse_id, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :organization_id }
end
