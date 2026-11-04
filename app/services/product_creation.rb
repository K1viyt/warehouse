class ProductCreation
  def self.call(product, warehouse:)
    ApplicationRecord.transaction do
      product.save!
      product.stock_balances.create!(warehouse: warehouse, quantity: 0)
    end
  end
end
