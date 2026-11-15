require "test_helper"

class StockBalanceBackfillTest < ActiveSupport::TestCase
  test "fills missing stock balances" do
  product_without_balance = Product.create!(organization: organizations(:one), name: "Болт", sku: "B03", unit: "шт")
  product_with_balance = Product.create!(organization: organizations(:one), name: "Дюбель", sku: "D04", unit: "шт")
  product_with_balance.stock_balances.create!(warehouse: warehouses(:one), quantity: 25)

  StockBalanceBackfill.call(warehouse: warehouses(:one))
  product_without_balance.reload.stock_balances.find_by!(warehouse: warehouses(:one)).quantity
  product_with_balance.reload.stock_balances.find_by!(warehouse: warehouses(:one)).quantity

  assert_equal 0, product_without_balance.stock_balances.find_by!(warehouse: warehouses(:one)).quantity
  assert_equal 25, product_with_balance.stock_balances.find_by!(warehouse: warehouses(:one)).quantity

  balances_before = StockBalance.count
  StockBalanceBackfill.call(warehouse: warehouses(:one))
  product_without_balance.reload.stock_balances.find_by!(warehouse: warehouses(:one)).quantity
  product_with_balance.reload.stock_balances.find_by!(warehouse: warehouses(:one)).quantity

  assert_equal 0, product_without_balance.stock_balances.find_by!(warehouse: warehouses(:one)).quantity
  assert_equal 25, product_with_balance.stock_balances.find_by!(warehouse: warehouses(:one)).quantity
  assert_equal balances_before, StockBalance.count
  end
end
