require "test_helper"

class TenantIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    @admin = create_user(name: "Администратор", email_address: "admin@example.test", password: "secret123", role: "admin", status: "active")
    @other = Organization.create!(name: "Другая фирма", legal_form: "ooo")
    @other_warehouse = @other.warehouses.create!(name: "Чужой склад")
    @other_product = @other.products.create!(name: "Чужой товар", sku: "FOREIGN", unit: "шт")
    @other_user = @other.users.create!(name: "Чужой сотрудник", email_address: "foreign@example.test", password: "secret123")
    post "/session", params: { login: { email_address: @admin.email_address, password: "secret123" } }
    assert_response :ok
  end

  test "catalog and direct product lookup exclude other firms" do
    get "/products"
    assert_response :ok
    assert_not_includes response.parsed_body.map { |product| product.fetch("id") }, @other_product.id
    get "/products/#{@other_product.id}"
    assert_response :not_found
  end

  test "administrator lists only own employees and cannot activate another firm user" do
    get "/admin/users"
    assert_response :ok
    assert_equal @organization.users.count, response.parsed_body.fetch("pagination").fetch("total")
    assert_not_includes response.parsed_body.fetch("users").map { |user| user.fetch("id") }, @other_user.id
    get "/admin/users/pending"
    assert_response :ok
    assert_not_includes response.parsed_body.map { |user| user.fetch("id") }, @other_user.id
    patch "/admin/users/#{@other_user.id}/activate"
    assert_response :not_found
    assert @other_user.reload.pending?
    patch "/admin/users/#{@other_user.id}/block"
    assert_response :not_found
    patch "/admin/users/#{@other_user.id}/unblock"
    assert_response :not_found
  end

  test "product organization comes from session rather than submitted attributes" do
    post "/products", params: { product: { name: "Наш товар", sku: "OWN", unit: "шт", organization_id: @other.id } }
    assert_response :created
    assert_equal @organization.id, Product.find(response.parsed_body.fetch("id")).organization_id
  end

  test "product creation cannot target another firm warehouse" do
    assert_no_difference("Product.count") do
      post "/products", params: { warehouse_id: @other_warehouse.id, product: { name: "Наш товар", sku: "OWN", unit: "шт" } }
    end
    assert_response :unprocessable_entity
  end

  test "public registration does not guess or accept firm when multiple firms exist" do
    delete "/session"
    assert_no_difference("User.count") do
      post "/registrations", params: { user: { name: "Новый", email_address: "new@example.test", password: "secret123", organization_id: @other.id } }
    end
    assert_response :unprocessable_entity
  end

  test "multiple accessible warehouses require an explicit selection for product creation" do
    @organization.warehouses.create!(name: "Второй склад")
    assert_no_difference("Product.count") do
      post "/products", params: { product: { name: "Товар", sku: "SELECT-WAREHOUSE", unit: "шт" } }
    end
    assert_response :unprocessable_entity
  end

  test "activation grants the pending assignment within own organization" do
    user = create_user(name: "Новый оператор", email_address: "pending@example.test", password: "secret123")
    assert user.warehouse_memberships.first.pending?
    patch "/admin/users/#{user.id}/activate"
    assert_response :ok
    assert user.reload.active?
    assert user.warehouse_memberships.first.active?
  end
end
