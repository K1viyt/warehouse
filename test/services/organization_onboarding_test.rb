require "test_helper"

class OrganizationOnboardingTest < ActiveSupport::TestCase
  def attributes
    { code: "uyutstroy", name: "УЮТСТРОЙ", legal_form: "ooo", warehouse_name: "Центральный",
      admin_name: "Администратор", admin_email: "first-admin@example.test", admin_password: "initial-password" }
  end

  test "creates firm and admin atomically and repeat never resets password" do
    organization = OrganizationOnboarding.call(**attributes)
    admin = organization.users.sole
    assert admin.admin?
    assert admin.active?
    assert admin.password_change_required?
    admin.update!(password: "changed-password")
    assert_no_difference([ "Organization.count", "User.count", "StockWarehouse.count", "AccessEvent.count" ]) do
      assert_equal organization, OrganizationOnboarding.call(**attributes.merge(admin_password: "replacement-password"))
    end
    assert admin.reload.authenticate("changed-password")
  end

  test "refuses email reassignment and rolls back invalid admin" do
    create_user(name: "Existing", email_address: attributes[:admin_email], password: "secret123")
    assert_no_difference([ "Organization.count", "StockWarehouse.count" ]) do
      assert_raises(OrganizationOnboarding::Conflict) { OrganizationOnboarding.call(**attributes) }
    end
    assert_no_difference([ "Organization.count", "StockWarehouse.count" ]) do
      assert_raises(ActiveRecord::RecordInvalid) { OrganizationOnboarding.call(**attributes.merge(admin_email: "new@example.test", admin_password: "short")) }
    end
  end
end
