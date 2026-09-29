require "test_helper"

class ProductsTest < ActionDispatch::IntegrationTest
  test "rejects product with empty name" do
    sign_in_active_user
    assert_no_difference("Product.count") do
     post "/products", params: {
    product: { sku: "TEST-001", name: "", unit: "pcs" }
}
    end

    assert_response :unprocessable_entity
  end

  test "creates product with valid name" do
    sign_in_active_user
    assert_difference("Product.count", 1) do
      post "/products", params: {
    product: { sku: "TEST-002", name: "Шуруп", unit: "pcs" }
}
    end

    assert_response :created
  end
  test "requires authentication" do
  get "/products"
  assert_response :unauthorized
  body = JSON.parse(response.body)
  assert_equal "Authentication required", body["error"]
  end

  test "rejects pending user" do
  User.create!(
    name: "Pending Operator",
    email_address: "operator@example.com",
    password: "secret123",
    password_confirmation: "secret123",
  )
  post "/session", params: {
    login: {
    email_address: "operator@example.com",
    password: "secret123"
    }
  }
  assert_response :ok

  get "/products"
  assert_response :forbidden
  body=JSON.parse(response.body)
  assert_equal "Account is pending activation", body["error"]
end

test "rejects blocked user with existing session" do
  user = User.create!(name: "Blocked Operator",
    email_address: "operator@example.com",
    password: "secret123",
    password_confirmation: "secret123",
    status: "active")

    post "/session", params: {
    login: {
      email_address: "operator@example.com",
      password: "secret123"
    }
  }
  assert_response :ok
  user.blocked!

  get "/products"
  assert_response :forbidden
    body = JSON.parse(response.body)
  assert_equal "Your access has been blocked", body["error"]
  get "/me"
  assert_response :unauthorized
end


  private

def sign_in_active_user
  User.create!(
    name: "Active Operator",
    email_address: "operator@example.com",
    password: "secret123",
    password_confirmation: "secret123",
    status: "active"
  )

  post "/session", params: {
    login: {
      email_address: "operator@example.com",
      password: "secret123"
    }
  }

  assert_response :ok
end
end
