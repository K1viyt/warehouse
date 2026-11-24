class WarehouseLine < ApplicationRecord
  belongs_to :warehouse_document
  belongs_to :product
  belongs_to :organization
end
