require "test_helper"
require "minitest/mock"


class ProductCreationTest < ActiveSupport::TestCase
  test "creates product with zero stock balance" do
    # Подготовка
    product = Product.new(sku: "D-62", name: "Дюбель", unit: "шт")
    ProductCreation.call(product)
    # Действие
    saved_product = Product.find(product.id)

    # Проверка
    assert_equal 0, saved_product.stock_balance.quantity
  end
  test "rolls back product when stock balance creation fails" do
  product = Product.new(
    sku: "ROLLBACK-62",
    name: "Дюбель",
    unit: "шт"
  )
  products_before = Product.count
  failure = ->(quantity:) do
    assert product.persisted?, "Товар должен сохраниться до ошибки остатка"
    StockBalance.create!(product: product, quantity: -1)
    end
    product.stub(:create_stock_balance!, failure) do
   assert_raises(ActiveRecord::RecordInvalid) do
      ProductCreation.call(product)
    end
  end

  assert_equal products_before, Product.count
  end
end
