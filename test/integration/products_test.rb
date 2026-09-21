require "test_helper"

class ProductsTest < ActionDispatch::IntegrationTest
  test "rejects product with empty name" do
    assert_no_difference("Product.count") do
     post "/products", params: {
    product: { sku: "TEST-001", name: "", unit: "pcs" }
}
    end

    assert_response :unprocessable_entity
  end

  test "creates product with valid name" do
    assert_difference("Product.count", 1) do
      post "/products", params: {
    product: { sku: "TEST-002", name: "Шуруп", unit: "pcs" }
}
    end

    assert_response :created
  end
end
