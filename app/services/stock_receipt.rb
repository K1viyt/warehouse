class StockReceipt
  class AccessDenied < StandardError; end

  def self.call(product:, warehouse:, quantity:, user:, reason:)
    unless user.active? && user.organization_id == warehouse.organization_id &&
        product.organization_id == warehouse.organization_id && user.accessible_warehouses.exists?(id: warehouse.id)
      raise AccessDenied, "Warehouse access denied"
    end

    balance = warehouse.stock_balances.find_by!(product_id: product.id)
    balance.with_lock do
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
