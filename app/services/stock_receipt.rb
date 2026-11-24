class StockReceipt
  class AccessDenied < StandardError; end

  def self.call(product:, warehouse:, quantity:, user:, reason:)
    unless StockWarehousePolicy.new(user, warehouse).operate? && user.organization_id == warehouse.organization_id &&
        product.organization_id == warehouse.organization_id && user.accessible_warehouses.exists?(id: warehouse.id)
      raise AccessDenied, "Warehouse access denied"
    end

    StockBalance.transaction do
      product = user.organization.products.lock("FOR SHARE").find(product.id)
      raise AccessDenied, "Товар уже в архиве" if product.archived_at
      balance = warehouse.stock_balances.lock.find_by!(product_id: product.id)
      balance.quantity += quantity
      balance.save!
      StockMovement.create!(
        product: product,
        warehouse: warehouse,
        user: user,
        quantity: quantity,
        movement_type: "receipt",
        reason: reason
      )
    end
  end
end
