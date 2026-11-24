require "test_helper"

class WarehouseOperationsTest < ActionDispatch::IntegrationTest
  setup do
    @company = organizations(:one)
    @destination = warehouses(:one)
    @source = @company.warehouses.create!(name: "Север")
    @operator = create_user(name: "Оператор", email_address: "flow@example.test", password: "secret123", status: "active")
    @manager = create_user(name: "Администратор", email_address: "flow-admin@example.test", password: "secret123", status: "active", role: "admin")
    @product = @company.products.create!(name: "Шпилька", sku: "FLOW", unit: "шт")
    @balance = @source.stock_balances.create!(organization: @company, product: @product, quantity: 20)
    login(@operator)
  end

  test "request reserves, ships and arrives exactly once at its destination" do
    id = make("transfer", 12)["id"]
    transition(id, "approve", :forbidden)
    login(@manager)
    transition(id, "approve")
    assert_equal [ 20, 12 ], [ @balance.reload.quantity, @balance.reserved ]
    make("issue", 9, warehouse: @source, status: :conflict)
    transition(id, "ship")
    assert_equal [ 8, 0 ], [ @balance.reload.quantity, @balance.reserved ]
    transition(id, "ship", :forbidden)
    assert_difference("StockMovement.count", 1) { transition(id, "receive") }
    transition(id, "receive", :forbidden)
    assert_equal 12, @destination.stock_balances.find_by!(product: @product).quantity
    get "/warehouses/#{@destination.id}/documents"
    assert_equal %w[pending approved shipped received], response.parsed_body["rows"].first["events"].pluck("state")
  end

  test "cancelling an approved transfer releases its reservation" do
    id = make("transfer", 4)["id"]
    login(@manager)
    transition(id, "approve")
    transition(id, "cancel")
    assert_equal [ 20, 0 ], [ @balance.reload.quantity, @balance.reserved ]
    transition(id, "ship", :forbidden)
  end

  test "purchase changes balance only on receipt and duplicate posts are safe" do
    key = SecureRandom.uuid
    first = make("purchase", 7, key: key)
    assert_no_difference("WarehouseDocument.count") { assert_equal first["id"], make("purchase", 7, key: key)["id"] }
    make("purchase", 6, key: key, status: :conflict)
    login(@manager)
    assert_no_difference("StockMovement.count") { transition(first["id"], "approve") }
    transition(first["id"], "receive")
    assert_equal 7, @destination.stock_balances.find_by!(product: @product).quantity
  end

  test "journal correction preserves original and cannot be applied twice" do
    key = SecureRandom.uuid
    make("receipt", 15, key: key)
    assert_no_difference("StockMovement.count") { make("receipt", 15, key: key) }
    make("issue", "1.5", status: :unprocessable_entity)
    make("issue", 3)
    get "/warehouses/#{@destination.id}/journal", params: { movement_type: "issue" }
    row = response.parsed_body.fetch("rows").sole
    assert_equal @operator.name, row["operator"]
    url = "/warehouses/#{@destination.id}/journal/#{row['id']}/reverse"
    post url, params: { reason: "Исправление" }
    assert_response :forbidden
    login(@manager)
    assert_difference("StockMovement.count", 1) { post url, params: { reason: "Исправление" } }
    assert_response :created
    post url, params: { reason: "Повтор" }
    assert_response :conflict
    assert_equal 15, @destination.stock_balances.find_by!(product: @product).quantity
  end

  test "foreign firm and unassigned warehouses cannot be used by changing IDs" do
    own_doc = make("purchase", 6)
    foreign = Organization.create!(name: "Другая фирма")
    site = foreign.warehouses.create!(name: "Чужой склад")
    other_product = foreign.products.create!(sku: @product.sku, name: "Чужая позиция", unit: "шт")
    make("receipt", 1, product: other_product, status: :not_found)
    make("transfer", 1, source: site, status: :not_found)
    make("issue", 1, warehouse: @source, status: :not_found)
    %w[inventory journal documents].each do |path|
      get "/warehouses/#{site.id}/#{path}"
      assert_response :not_found
    end
    get "/warehouses/#{@destination.id}/inventory"
    assert_not_includes response.body, other_product.name
    assert_not_includes response.body, site.name
    outsider = foreign.users.create!(name: "Другой админ", email_address: "other-flow@example.test", password: "secret123", status: "active", role: "admin")
    login(outsider)
    transition(own_doc["id"], "approve", :not_found)
    delete "/products/#{@product.id}"
    assert_response :not_found
    assert_equal "pending", WarehouseDocument.find(own_doc["id"]).state
  end

  test "empty card can be deleted and history can only be archived after stock is empty" do
    patch "/products/#{@product.id}", params: { product: { name: "Шпилька М8" } }
    assert_response :ok
    delete "/products/#{@product.id}"
    assert_response :conflict
    make("receipt", 3)
    make("issue", 3)
    login(@manager)
    make("issue", 20, warehouse: @source)
    delete "/products/#{@product.id}"
    assert_response :conflict
    post "/products/#{@product.id}/archive"
    assert_response :no_content
    make("receipt", 1, status: :unprocessable_entity)
    empty = @company.products.create!(name: "Временный", sku: "TEMP", unit: "шт")
    delete "/products/#{empty.id}"
    assert_response :no_content
    assert_not Product.exists?(empty.id)
  end

  private

  def login(user)
    post "/session", params: { login: { email_address: user.email_address, password: "secret123" } }, as: :json
    assert_response :ok
  end

  def make(kind, quantity, warehouse: @destination, source: @source, product: @product, key: SecureRandom.uuid, status: :created)
    post "/warehouse_documents", params: { document: { kind: kind, warehouse_id: warehouse.id, source_id: source.id,
      reason: "Для монтажа", request_key: key, lines: [ { product_id: product.id, quantity: quantity } ] } }, as: :json
    assert_response status
    response.parsed_body
  end

  def transition(id, action, status = :ok)
    patch "/warehouse_documents/#{id}", params: { transition: action }, as: :json
    assert_response status
  end
end
