require "test_helper"

class StockBalanceTest < ActiveSupport::TestCase
 test "quantity return false" do
 balance = stock_balances(:one)
 balance.quantity = -1
 assert_not balance.valid?
 assert_not_empty balance.errors[:quantity]
end
 test "quantity zero return true" do
 balance = stock_balances(:one)
 balance.quantity = 0
 assert balance.valid?
 assert_empty balance.errors[:quantity]
end
end
