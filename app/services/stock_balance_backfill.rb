class StockBalanceBackfill
  def self.call(warehouse:)
    products = warehouse.organization.products.where.not(id: warehouse.stock_balances.select(:product_id))
    products.each do |product|
      product.stock_balances.create!(warehouse: warehouse, quantity: 0)
    end
  end
end
