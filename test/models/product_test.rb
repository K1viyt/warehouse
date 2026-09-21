require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "product requires name" do
    product = Product.new(name: "")
    assert_not product.valid?
    assert_includes product.errors[:name], "can't be blank"
  end
  test "product name valid true" do
    product = Product.new(name: "Шуруп")
    assert product.valid?
    assert_empty product.errors[:name]
  end
end
