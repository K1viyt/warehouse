require "test_helper"

class CompanyAccessTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_user(name: "Админ", email_address: "access-admin@example.test", password: "secret123", role: "admin", status: "active")
    @user = create_user(name: "Сотрудник", email_address: "access-operator@example.test", password: "secret123")
    @warehouse = @admin.organization.warehouses.create!(name: "Второй")
    @second = @user.warehouse_memberships.create!(organization: @user.organization, warehouse: @warehouse)
    post "/session", params: { login: { email_address: @admin.email_address, password: "secret123" } }
  end

  test "activation requires selection when multiple assignments are pending" do
    patch "/admin/users/#{@user.id}/activate"
    assert_response :conflict
    assert @user.reload.pending?
    assert_equal 2, @user.warehouse_memberships.pending.count
    patch "/admin/users/#{@user.id}/activate", params: { membership_id: @second.id }
    assert_response :ok
    assert @user.reload.active?
    assert @second.reload.active?
    assert @user.warehouse_memberships.find_by!(warehouse_id: warehouses(:one).id).pending?
  end

  test "manager role applies to one warehouse without giving company admin rights" do
    patch "/admin/warehouse_memberships/#{@second.id}", params: { membership: { role: "warehouse_manager", status: "active" } }
    assert_response :ok
    assert @user.reload.operator?
    assert StockWarehousePolicy.new(@user, @warehouse).manage?
    assert_not StockWarehousePolicy.new(@user, warehouses(:one)).manage?
    post "/session", params: { login: { email_address: @user.email_address, password: "secret123" } }
    get "/admin/users"
    assert_response :forbidden
    get "/me"
    assert_equal "warehouse_manager", response.parsed_body.fetch("memberships").find { |item| item["id"] == @second.id }.fetch("role")
  end

  test "invalid role and cross company assignment cannot be saved" do
    patch "/admin/warehouse_memberships/#{@second.id}", params: { membership: { role: "admin", status: "active" } }
    assert_response :unprocessable_entity
    assert @second.reload.operator?
    foreign = Organization.create!(name: "Чужая")
    warehouse = foreign.warehouses.create!(name: "Чужой")
    assert_no_difference("WarehouseMembership.count") do
      post "/admin/warehouse_memberships", params: { membership: { user_id: @user.id, warehouse_id: warehouse.id, status: "active" } }
    end
    assert_response :not_found
  end

  test "blocking account dominates active membership and approval cannot unblock it" do
    @user.update!(status: "blocked")
    patch "/admin/warehouse_memberships/#{@second.id}", params: { membership: { status: "active" } }
    assert_response :conflict
    assert @user.reload.blocked?
    assert_not StockWarehousePolicy.new(@user, @warehouse).operate?
  end

  test "temporary password cannot bypass warehouse protection by calling services directly" do
    @user.update!(status: "active", password_change_required: true)
    @second.update!(status: "active")
    product = products(:one)
    assert_raises(StockIssue::AccessDenied) do
      StockIssue.call(product: product, warehouse: @warehouse, amount: 1, user: @user, reason: "test")
    end
    assert_raises(StockReceipt::AccessDenied) do
      StockReceipt.call(product: product, warehouse: @warehouse, quantity: 1, user: @user, reason: "test")
    end
  end

  test "blocking and unblocking records actor and revokes existing session" do
    @user.active!
    other_session = open_session
    other_session.post "/session", params: { login: { email_address: @user.email_address, password: "secret123" } }
    patch "/admin/users/#{@user.id}/block"
    assert_response :ok
    assert_equal "user_blocked", AccessEvent.where(user: @user).order(:id).last.action
    patch "/admin/users/#{@user.id}/unblock"
    assert_response :ok
    assert_equal "user_unblocked", AccessEvent.where(user: @user).order(:id).last.action
    other_session.get "/me"
    assert_equal 401, other_session.response.status
  end

  test "new warehouse has zero balances and does not grant operator access" do
    post "/admin/warehouses", params: { warehouse: { name: "Новый", organization_id: 0 } }
    assert_response :created
    warehouse = @admin.organization.warehouses.find(response.parsed_body.fetch("id"))
    assert_equal @admin.organization.products.count, warehouse.stock_balances.count
    assert warehouse.stock_balances.all? { |balance| balance.quantity.zero? }
    assert_not @user.accessible_warehouses.exists?(id: warehouse.id)
  end

  test "search is scoped and supports normalized exact email and name prefix" do
    get "/admin/users", params: { q: " ACCESS-OPERATOR@EXAMPLE.TEST " }
    assert_response :ok
    assert_equal [ @user.id ], response.parsed_body.fetch("users").map { |item| item.fetch("id") }
    get "/admin/users", params: { q: "Сот" }
    assert_equal [ @user.id ], response.parsed_body.fetch("users").map { |item| item.fetch("id") }
  end

  test "audit is scoped and records membership changes without secrets" do
    patch "/admin/warehouse_memberships/#{@second.id}", params: { membership: { status: "active" } }
    get "/admin/access_events", params: { user_id: @user.id }
    assert_response :ok
    event = response.parsed_body.fetch("events").first
    assert_equal "warehouse_membership_changed", event.fetch("action")
    assert_equal @admin.id, event.fetch("actor_id")
    assert_not response.body.include?("password_digest")
    foreign = Organization.create!(name: "Чужая")
    user = foreign.users.create!(name: "Чужой", email_address: "foreign-event@example.test", password: "secret123")
    get "/admin/access_events", params: { user_id: user.id }
    assert_response :not_found
  end
end
