require "test_helper"

class StockReceiptTest < ActiveSupport::TestCase
  test "increases balance and records receipt" do
    # Подготовка
    product = Product.create!(name: "Шуруп", sku: "TEST-001", unit: "кг")
    product.create_stock_balance!(quantity: 20)
    user = User.create!(name: "Pending Operator",
    email_address: "operator@example.com",
    password: "secret123",
    password_confirmation: "secret123",)
    movements_before = StockMovement.count
    # Действие
    StockReceipt.call(
    product: product,
    quantity: 15,
    user: user,
    reason: "Поставка"
    )
    movement = StockMovement.find_by!(product_id: product.id)
   # Проверка
   assert_equal 35, product.reload.stock_balance.quantity
   assert_equal 15, movement.quantity
   assert_equal "receipt", movement.movement_type
   assert_equal "Поставка", movement.reason
   assert_equal user.id, movement.user_id
  assert_equal movements_before + 1, StockMovement.count
  end
  test "rolls back balance when movement is invalid" do
    # Подготовка
    product = Product.create!(name: "Шуруп", sku: "TEST-001", unit: "кг")
    product.create_stock_balance!(quantity: 20)
    user = User.create!(name: "Pending Operator",
    email_address: "operator@example.com",
    password: "secret123",
    password_confirmation: "secret123",)
    movements_before = StockMovement.count
   # Действие
   assert_raises(ActiveRecord::RecordInvalid) do
      StockReceipt.call(
        product: product,
        quantity: 15,
        user: user,
        reason: ""
      )
  end


  # Проверка
  assert_equal 20, product.reload.stock_balance.quantity
  assert_equal movements_before, StockMovement.count
end
test "rejects negative receipt without changing stock" do
   product = Product.create!(name: "Шуруп", sku: "TEST-001", unit: "кг")
    product.create_stock_balance!(quantity: 20)
    user = User.create!(name: "Pending Operator",
    email_address: "operator@example.com",
    password: "secret123",
    password_confirmation: "secret123",)
    movements_before = StockMovement.count
   # Действие

   error = assert_raises(ActiveRecord::RecordInvalid) do
  StockReceipt.call(
    product: product,
    quantity: -5,
    user: user,
    reason: "Поставка"
  )
end


  # Проверка
  assert_not_empty error.record.errors[:quantity]
  assert_equal 20, product.reload.stock_balance.quantity
  assert_equal movements_before, StockMovement.count
end
end
