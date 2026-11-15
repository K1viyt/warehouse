require "test_helper"

class TenantConstraintsTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @warehouse = warehouses(:one)
    @other = Organization.create!(name: "Другая фирма", legal_form: "ip")
    @other_warehouse = @other.warehouses.create!(name: "Другой склад")
    @product = products(:one)
  end

  test "same SKU belongs to independent organization catalogs" do
    assert @other.products.create!(name: "Другой товар", sku: @product.sku, unit: "шт").persisted?
    duplicate = @organization.products.new(name: "Дубликат", sku: @product.sku, unit: "шт")
    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordNotUnique) do
      ApplicationRecord.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
  end

  test "each warehouse has its own quantity for the same product" do
    warehouse = @organization.warehouses.create!(name: "Второй склад")
    balance = @product.stock_balances.create!(warehouse: warehouse, quantity: 25)
    assert_equal 25, balance.quantity
    assert_equal 9.99.to_d, @warehouse.stock_balances.find_by!(product: @product).quantity
    assert_raises(ActiveRecord::RecordNotUnique) do
      ApplicationRecord.transaction(requires_new: true) do
        StockBalance.new(organization: @organization, product: @product, warehouse: warehouse, quantity: 0).save!(validate: false)
      end
    end
  end

  test "database rejects a balance linked to another organization warehouse" do
    balance = stock_balances(:one)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ApplicationRecord.transaction(requires_new: true) { balance.update_columns(warehouse_id: @other_warehouse.id) }
    end
    assert_equal @warehouse.id, balance.reload.warehouse_id
  end

  test "database rejects membership of another organization employee" do
    user = User.create!(organization: @other, name: "Другой сотрудник", email_address: "foreign@example.test", password: "secret123")
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ApplicationRecord.transaction(requires_new: true) do
        WarehouseMembership.new(organization: @organization, warehouse: @warehouse, user: user).save!(validate: false)
      end
    end
  end

  test "database rejects a movement linked to another organization user" do
    user = User.create!(organization: @other, name: "Другой сотрудник", email_address: "foreign@example.test", password: "secret123")
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ApplicationRecord.transaction(requires_new: true) do
        StockMovement.new(organization: @organization, warehouse: @warehouse, product: @product,
          user: user, quantity: 1, movement_type: "receipt", reason: "Проверка").save!(validate: false)
      end
    end
  end

  test "receipt denies access to a warehouse outside employee assignments" do
    user = create_user(name: "Оператор", email_address: "operator@example.test", password: "secret123", status: "active")
    warehouse = @organization.warehouses.create!(name: "Второй склад")
    balance = @product.stock_balances.create!(warehouse: warehouse, quantity: 10)
    assert_no_difference("StockMovement.count") do
      assert_raises(StockReceipt::AccessDenied) do
        StockReceipt.call(product: @product, warehouse: warehouse, user: user, quantity: 5, reason: "Поставка")
      end
    end
    assert_equal 10, balance.reload.quantity
  end

  test "backfill fills only the selected warehouse organization" do
    @other.products.create!(name: "Чужой товар", sku: "FOREIGN", unit: "шт")
    warehouse = @organization.warehouses.create!(name: "Второй склад")
    StockBalanceBackfill.call(warehouse: warehouse)
    assert_equal @organization.products.count, warehouse.stock_balances.count
    assert_equal 0, @other_warehouse.stock_balances.count
    assert_not warehouse.stock_balances.exists?(organization: @other)
  end

  test "manager permissions are limited to active warehouse assignments" do
    user = create_user(name: "Ответственный", email_address: "manager@example.test", password: "secret123", status: "active")
    membership = user.warehouse_memberships.first
    membership.update!(role: "warehouse_manager")
    assert membership.warehouse_manager?
    assert user.accessible_warehouses.exists?(@warehouse.id)
    membership.blocked!
    assert_not user.accessible_warehouses.exists?(@warehouse.id)
  end

  test "product creation rolls back when the warehouse belongs to another firm" do
    product = @organization.products.new(name: "Болт", sku: "CROSS-FIRM", unit: "шт")
    assert_no_difference("Product.count") do
      assert_raises(ActiveRecord::RecordInvalid) do
        ProductCreation.call(product, warehouse: @other_warehouse)
      end
    end
  end
end
