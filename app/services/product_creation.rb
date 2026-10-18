class ProductCreation
  def self.call(product)
    ApplicationRecord.transaction do
      product.save!
      product.create_stock_balance!(quantity: 0)
    end
  end
end
