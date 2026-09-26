require "test_helper"
class RegistrationsTest < ActionDispatch::IntegrationTest
  test "creates pending user" do
    assert_difference("User.count", 1) do
    post "/registrations", params: {
  user: {
    name: "Vlad",
    email_address: "vlad@example.com",
    password: "secret123",
    password_confirmation: "secret123"
  }
}
  end
  assert_response :created
  created_user = User.order(:id).last
  assert created_user.pending?
  assert created_user.operator?
  assert created_user.authenticate("secret123")
end
test "rejects repeated email" do
  User.create!(
    name: "Vlad",
    email_address: "vlad@example.com",
    password: "secret123",
    password_confirmation: "secret123"
  )

  assert_no_difference("User.count") do
    post "/registrations", params: {
      user: {
        name: "Vlad1",
        email_address: "VLAD@EXAMPLE.COM",
        password: "secret123",
        password_confirmation: "secret123"
      }
    }
  end

  assert_response :unprocessable_entity

  assert_instance_of String, response.body

  body = JSON.parse(response.body)

  assert_instance_of Hash, body
  assert_includes body["errors"], "Email address has already been taken"
end
end
