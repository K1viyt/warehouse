require "test_helper"

class ProfileTest < ActionDispatch::IntegrationTest
  test "rejects request without session" do
    get "/me"

    assert_response :unauthorized
  end

  test "returns profile after login" do
    user = User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    get "/me"

    assert_response :ok

    body = JSON.parse(response.body)

    assert_equal user.id, body["id"]
    assert_equal "vlad@example.com", body["email_address"]
    assert_equal "pending", body["status"]
  end
end
