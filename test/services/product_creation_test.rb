require "test_helper"
require "minitest/mock"

class ProductCreationTest < ActiveSupport::TestCase
  test "creates product with zero stock balance in the selected warehouse" do
    product = organizations(:one).products.new(sku: "D-62", name: "Дюбель", unit: "шт")
    ProductCreation.call(product, warehouse: warehouses(:one))
    assert_equal 0, product.reload.stock_balances.find_by!(warehouse: warehouses(:one)).quantity
  end

  test "rolls back product when stock balance creation fails" do
    product = organizations(:one).products.new(sku: "ROLLBACK-62", name: "Дюбель", unit: "шт")
    failure = ->(**attributes) do
      assert product.persisted?, "Товар должен сохраниться до ошибки остатка"
      StockBalance.create!(product: product, warehouse: attributes.fetch(:warehouse), quantity: -1)
    end
    assert_no_difference("Product.count") do
      product.stock_balances.stub(:create!, failure) do
        assert_raises(ActiveRecord::RecordInvalid) do
          ProductCreation.call(product, warehouse: warehouses(:one))
        end
      end
    end
  end
end
