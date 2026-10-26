require "test_helper"

class StockMovementTest < ActiveSupport::TestCase
  test "rejects zero quantity" do
  # Подготовка
  product = products(:one)

  user = User.create!(
  name: "Оператор",
  email_address: "movement-test@example.com",
  password: "secret123"
)
  movement = StockMovement.new(
  product: product,
  user: user,
  quantity: 0,
  movement_type: "receipt",
  reason: "Поставка"
)
  # Проверка
  assert_not movement.valid?
  assert_not_empty movement.errors[:quantity]
end
test "accepts valid receipt" do
  # Подготовка
  product = products(:one)
  user = User.create!(
  name: "Оператор",
  email_address: "movement-test@example.com",
  password: "secret123"
)
  movement = StockMovement.new(
  product: product,
  user: user,
  quantity: 15,
  movement_type: "receipt",
  reason: "Поставка"
)
  # Проверка
  assert movement.valid?
end
test "rejects unknown movement type" do
  # Подготовка
  product = products(:one)
  user = User.create!(
  name: "Оператор",
  email_address: "movement-test@example.com",
  password: "secret123"
)
  movement = StockMovement.new(
  product: product,
  user: user,
  quantity: 15,
  movement_type: "other",
  reason: "Поставка"
)
  # Проверка
  assert_not movement.valid?
  assert_not_empty movement.errors[:movement_type]
end
end
