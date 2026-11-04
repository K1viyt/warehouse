class Product < ApplicationRecord
    belongs_to :organization
   validates :name, presence: true
    validates :sku, presence: true, uniqueness: { scope: :organization_id }
    validates :unit, presence: true, inclusion: { in: [ "шт", "кг" ] }
    has_many :stock_balances, dependent: :restrict_with_error
    has_many :stock_movements, dependent: :restrict_with_error
end
