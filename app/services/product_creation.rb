class ProductCreation
  def self.call(product, warehouse:)
    ApplicationRecord.transaction do
      product.organization.lock!
      product.save!
      unless warehouse.organization_id == product.organization_id
        product.errors.add(:organization, "Склад принадлежит другой фирме")
        raise ActiveRecord::RecordInvalid, product
      end
      product.organization.warehouses.each { |site| product.stock_balances.create!(warehouse: site, quantity: 0) }
    end
  end
end
