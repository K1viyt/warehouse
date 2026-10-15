class Product < ApplicationRecord
   validates :name, presence: true
    validates :sku, presence: true, uniqueness: true
    validates :unit, presence: true, inclusion: { in: [ "шт", "кг" ] }
    has_one :stock_balance
end
