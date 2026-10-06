require "test_helper"

class SessionsTest < ActionDispatch::IntegrationTest
  test "authenticates pending user" do
    user = User.create!(
      name: "Vladislav",
      email_address: "vlad@exampl1.com",
      password: "secret123",
      password_confirmation: "secret123"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@exampl1.com",
        password: "secret123"
      }
    }

    assert_response :ok

    body = JSON.parse(response.body)

    assert_equal user.id, body["id"]
    assert_equal "pending", body["status"]
  end

  test "rejects invalid password" do
    User.create!(
      name: "Vladislav",
      email_address: "vlad@exampl1.com",
      password: "secret123",
      password_confirmation: "secret123"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@exampl1.com",
        password: "wrong-password"
      }
    }

    assert_response :unauthorized

    body = JSON.parse(response.body)

    assert_equal "Invalid email or password", body["error"]
  end

  test "rejects blocked user" do
    User.create!(
      name: "Vladislav",
      email_address: "vlad@exampl1.com",
      password: "secret123",
      password_confirmation: "secret123",
      status: "blocked"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@exampl1.com",
        password: "secret123"
      }
    }

    assert_response :forbidden

    body = JSON.parse(response.body)

    assert_equal "Your access has been blocked", body["error"]
  end

  test "logs out authenticated user" do
    User.create!(
      name: "Vladislav",
      email_address: "vlad@exampl1.com",
      password: "secret123",
      password_confirmation: "secret123"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@exampl1.com",
        password: "secret123"
      }
    }

    assert_response :ok

    delete "/session"

    assert_response :no_content

    get "/me"

    assert_response :unauthorized
  end

  test "normalizes email before authentication" do
    user = User.create!(
      name: "Vladislav",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123"
    )

    post "/session", params: {
      login: {
        email_address: " VLAD@EXAMPLE.COM ",
        password: "secret123"
      }
    }

    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal user.id, body["id"]
  end
end
