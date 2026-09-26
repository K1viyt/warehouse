require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "user valid" do
  user=User.new(
  name: "Vlad",
  email_address: "vlad@example.com",
  password: "secret123",
  password_confirmation: "secret123"
  )
  assert user.valid?
  assert user.pending?
  assert user.operator?
  assert_not user.admin?
  assert_not user.blocked?
  assert_not user.active?

  assert_equal "operator", user.role
  assert_equal "pending", user.status
  assert user.authenticate "secret123"
  assert_not user.authenticate "123456"
  end
end
