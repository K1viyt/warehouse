require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "user valid" do
  user=User.new(organization: organizations(:one),
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

test "users repid email" do
 create_user(
    name: "Vladislav",
    email_address: "vlad@exampl1.com",
    password: "secret123",
    password_confirmation: "secret123"
  )

  second_user = User.new(organization: organizations(:one),
    name: "Vadim",
    email_address: " VLAD@EXAMPL1.COM ",
    password: "secret123",
    password_confirmation: "secret123"
  )
assert_not second_user.valid?
assert_includes second_user.errors[:email_address], "has already been taken"
end
  test "email verification depends on confirmation date" do
  user = User.new

  assert_not user.email_verified?

  user.email_verified_at = Time.current

  assert user.email_verified?
  end
  test "finds user by email verification token" do
  user = create_user(
    name: "Оператор",
    email_address: "verification@example.com",
    password: "secret123"
  )

  token = user.generate_token_for(:email_verification)

  found_user = User.find_by_token_for(:email_verification, token)

  assert_equal user.id, found_user.id
end
  test "email verification token stops working after confirmation" do
  user = create_user(
    name: "Оператор",
    email_address: "verification@example.com",
    password: "secret123"
  )

  token = user.generate_token_for(:email_verification)

  user.update!(email_verified_at: Time.current)

  found_user = User.find_by_token_for(:email_verification, token)

  assert_nil found_user
  end
  test "email verification token expires" do
  user = create_user(
    name: "Оператор",
    email_address: "verification@example.com",
    password: "secret123"
  )

  token = user.generate_token_for(:email_verification)

  travel 31.minutes do
    found_user = User.find_by_token_for(:email_verification, token)

    assert_nil found_user
    end
  end
end
