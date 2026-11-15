require "test_helper"

class StockIssuesTest < ActionDispatch::IntegrationTest
  setup do
    @balance = stock_balances(:one)
    @balance.update!(quantity: 20)
    @user = create_user(status: "active", name: "Stock operator",
      email_address: "stock-issue@example.test", password: "secret123")
    post "/session", params: { login: { email_address: @user.email_address, password: "secret123" } }, as: :json
    assert_response :ok
  end

  test "decreases balance and records issue" do
    assert_difference("StockMovement.count", 1) { issue("7") }
    assert_response :created
    assert_equal 13, @balance.reload.quantity

    movement = StockMovement.find(response.parsed_body.fetch("id"))
    assert_equal @balance.product, movement.product
    assert_equal @balance.warehouse, movement.warehouse
    assert_equal @user, movement.user
    assert_equal "issue", movement.movement_type
    assert_equal "Order 120", movement.reason
    assert_equal 7, movement.quantity
  end

  test "returns a conflict when stock is insufficient" do
    assert_no_difference("StockMovement.count") { issue("21") }
    assert_response :conflict
    assert_equal 20, @balance.reload.quantity
  end

  test "rolls back the balance if the movement is invalid" do
    assert_no_difference("StockMovement.count") { issue("7", reason: "") }
    assert_response :unprocessable_entity
    assert_equal 20, @balance.reload.quantity
  end

  test "hides a warehouse outside the operator's accessible warehouses" do
    warehouse = @user.organization.warehouses.create!(name: "Restricted")
    assert_no_difference("StockMovement.count") { issue("7", warehouse: warehouse) }
    assert_response :not_found
    assert_equal 20, @balance.reload.quantity
  end

  private

  def issue(amount, reason: "Order 120", warehouse: @balance.warehouse)
    post "/warehouses/#{warehouse.id}/stock_issues",
      params: { stock_issue: { product_id: @balance.product_id, amount: amount, reason: reason } }, as: :json
  end
end
