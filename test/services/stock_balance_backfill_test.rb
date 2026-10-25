require "test_helper"

class StockBalanceBackfillTest < ActiveSupport::TestCase
  test "fills missing stock balances" do
  product_without_balance = Product.create!(name: "Болт", sku: "B03", unit: "шт")
  product_with_balance = Product.create!(name: "Дюбель", sku: "D04", unit: "шт")
  product_with_balance.create_stock_balance!(quantity: 25)

  StockBalanceBackfill.call
  product_without_balance.reload.stock_balance.quantity
  product_with_balance.reload.stock_balance.quantity

  assert_equal 0, product_without_balance.stock_balance.quantity
  assert_equal 25, product_with_balance.stock_balance.quantity

  balances_before = StockBalance.count
  StockBalanceBackfill.call
  product_without_balance.reload.stock_balance.quantity
  product_with_balance.reload.stock_balance.quantity

  assert_equal 0, product_without_balance.stock_balance.quantity
  assert_equal 25, product_with_balance.stock_balance.quantity
  assert_equal balances_before, StockBalance.count
  end
end
