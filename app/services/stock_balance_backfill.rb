class StockBalanceBackfill
  def self.call
    products = Product.where.missing(:stock_balance)
    products.each do |product|
      product.create_stock_balance!(quantity: 0)
    end
  end
end
