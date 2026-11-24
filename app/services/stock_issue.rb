class StockIssue
  class InsufficientStock < StandardError
  end
  class InvalidAmount < StandardError
  end
  class AccessDenied < StandardError
  end

  def self.call(product:, warehouse:, amount:, reason:, user:)
     raise AccessDenied, "Доступ к складу закрыт" unless
      StockWarehousePolicy.new(user, warehouse).operate? &&
      user.organization_id == warehouse.organization_id &&
      product.organization_id == warehouse.organization_id &&
      user.accessible_warehouses.exists?(id: warehouse.id)

   requested_amount = BigDecimal(amount.to_s, exception: false)
   raise InvalidAmount, "Некоректное значение для списания" unless requested_amount && requested_amount.finite? && requested_amount.positive? && requested_amount.round(3) == requested_amount

   if product.unit == "шт" && !requested_amount.frac.zero?
     raise InvalidAmount, "Количество в штуках должно быть целым"
   end

    ApplicationRecord.transaction do
      product = user.organization.products.lock("FOR SHARE").find(product.id)
      raise InvalidAmount, "Товар уже в архиве" if product.archived_at
        updated_rows = warehouse.stock_balances.where(product_id: product.id).where("quantity - reserved >= ?", requested_amount).update_all([ "quantity = quantity - ?, updated_at = ?", requested_amount, Time.current ])

      raise InsufficientStock, "На этом складе недостаточно товара" if updated_rows.zero?

       StockMovement.create!(product: product,       # какой товар
         warehouse: warehouse,   # с какого склада
          quantity: requested_amount,      # сколько списали
          reason: reason,         # зачем
          user: user,             # кто списал
          movement_type: "issue"  # тип движения — списание
          )
    end
  end
end
