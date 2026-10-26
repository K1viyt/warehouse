class StockReceipt
  def self.call(product:, quantity:, user:, reason:)
    balance = product.stock_balance
    balance.with_lock do
      balance.quantity += quantity
      balance.save!
      StockMovement.create!(
        product: product,
        user: user,
        quantity: quantity,
        movement_type: "receipt",
        reason: reason
      )
    end
  end
end
