require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "product requires name" do
    product = Product.new(name: "")
    assert_not product.valid?
    assert_includes product.errors[:name], "can't be blank"
  end
  test "product name valid true" do
    product = Product.new(name: "Шуруп",
    unit: "шт", sku: "TEST-001")
    assert product.valid?
    assert_empty product.errors[:name]
  end
  test "chek unit return false" do
  product = Product.new(name: "Шуруп", sku: "TEST-002", unit: "г")
  assert_not product.valid?
  assert_not_empty product.errors[:unit]
end
test "check valid sku return false" do
Product.create!(name: "Шуруп", sku: "TEST-001", unit: "кг")
product_second = Product.new(name: "Шуруп", sku: "TEST-001", unit: "кг")
assert_not product_second.valid?
assert_not_empty product_second.errors[:sku]
end
end
