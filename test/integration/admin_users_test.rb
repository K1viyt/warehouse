require "test_helper"

class AdminUsersTest < ActionDispatch::IntegrationTest
  test "rejects active operator from pending users list" do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "operator",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    get "/admin/users/pending"

    assert_response :forbidden

    body = JSON.parse(response.body)
    assert_equal "Administrator access required", body["error"]
  end

  test "returns pending users to active admin" do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    pending_user = User.create!(
      name: "Pending Operator",
      email_address: "operator@example.com",
      password: "secret123",
      password_confirmation: "secret123"
    )

    assert_response :ok

    get "/admin/users/pending"

    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal 1, body.length

    pending_user_json = body.first

    assert_equal pending_user.id, pending_user_json["id"]
    assert_equal "pending", pending_user_json["status"]
    assert_not pending_user_json.key?("password_digest")
  end

  test "rejects unauthenticated user from pending users list" do
    get "/admin/users/pending"

    assert_response :unauthorized

    body = JSON.parse(response.body)
    assert_equal "Authentication required", body["error"]
  end

  test "activates pending user" do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    pending_user = User.create!(
      name: "Pending Operator",
      email_address: "operator@example.com",
      password: "secret123",
      password_confirmation: "secret123"
    )

    patch "/admin/users/#{pending_user.id}/activate"

    assert_response :ok

    pending_user.reload
    assert pending_user.active?

    body = JSON.parse(response.body)

    assert_equal pending_user.id, body["id"]
    assert_equal "active", body["status"]
    assert_not body.key?("password_digest")
  end

  test "rejects activation of active user" do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    active_user = User.create!(
      name: "Active Operator",
      email_address: "operator@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "operator",
      status: "active"
    )

    patch "/admin/users/#{active_user.id}/activate"

    assert_response :conflict

    body = JSON.parse(response.body)
    assert_equal "User is already active", body["error"]
  end

  test "rejects activation of blocked user" do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    blocked_user = User.create!(
      name: "Blocked Operator",
      email_address: "blocked@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      status: "blocked"
    )

    patch "/admin/users/#{blocked_user.id}/activate"

    assert_response :conflict

    body = JSON.parse(response.body)
    assert_equal "Blocked user must be unblocked first", body["error"]

    blocked_user.reload
    assert blocked_user.blocked?
  end

  test "returns not found when activating missing user" do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    patch "/admin/users/0/activate"

    assert_response :not_found

    body = JSON.parse(response.body)
    assert_equal "User not found", body["error"]
  end

  test "blocks active operator" do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    operator = User.create!(
      name: "Active Operator",
      email_address: "operator@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      status: "active"
    )

    patch "/admin/users/#{operator.id}/block"

    assert_response :ok

    operator.reload
    assert operator.blocked?

    body = JSON.parse(response.body)

    assert_equal operator.id, body["id"]
    assert_equal "blocked", body["status"]
    assert_not body.key?("password_digest")
  end

  test "rejects blocking already blocked user" do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    blocked_user = User.create!(
      name: "Blocked Operator",
      email_address: "blocked@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      status: "blocked"
    )

    patch "/admin/users/#{blocked_user.id}/block"

    assert_response :conflict

    body = JSON.parse(response.body)
    assert_equal "User is already blocked", body["error"]

    blocked_user.reload
    assert blocked_user.blocked?
  end

  test "blocks pending operator" do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    pending_user = User.create!(
      name: "Pending Operator",
      email_address: "operator@example.com",
      password: "secret123",
      password_confirmation: "secret123"
    )

    patch "/admin/users/#{pending_user.id}/block"

    assert_response :conflict

    body = JSON.parse(response.body)
    assert_equal "Pending user must be activated first", body["error"]

    pending_user.reload
    assert pending_user.pending?
  end

  test "rejects blocking administrator account" do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    admin = User.create!(
      name: "Admin",
      email_address: "second-admin@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    patch "/admin/users/#{admin.id}/block"

    assert_response :conflict

    body = JSON.parse(response.body)
    assert_equal "Administrator accounts cannot be blocked", body["error"]

    admin.reload
    assert admin.active?
  end

  test "returns not found when blocking missing user" do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    patch "/admin/users/0/block"

    assert_response :not_found

    body = JSON.parse(response.body)
    assert_equal "User not found", body["error"]
  end
  test "unblocking user return ok" do
  User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    blocked_user = User.create!(
      name: "Blocked Operator",
      email_address: "blocked@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      status: "blocked"
    )
    patch "/admin/users/#{blocked_user.id}/unblock"
    assert_response :ok
    blocked_user.reload
    assert blocked_user.active?
    body = JSON.parse(response.body)

    assert_equal blocked_user.id, body["id"]
    assert_equal "active", body["status"]
    assert_not body.key?("password_digest")
end
 test "unblocking active user return conflict" do
   User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    active_user = User.create!(
      name: "Active Operator",
      email_address: "operator@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      status: "active"
    )
    patch "/admin/users/#{active_user.id}/unblock"
    assert_response :conflict
    active_user.reload
    assert active_user.active?
    body = JSON.parse(response.body)
    assert_equal "User is already active", body["error"]
end
test "unblocking pending user return conflict" do
   User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    pending_user = User.create!(
      name: "Pending Operator",
      email_address: "operator@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      status: "pending"
    )
    patch "/admin/users/#{pending_user.id}/unblock"
    assert_response :conflict
    pending_user.reload
    assert pending_user.pending?
    body = JSON.parse(response.body)
    assert_equal "Pending user must be activated first", body["error"]
end
test "unblock not found user return not found" do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

    patch "/admin/users/0/unblock"

    assert_response :not_found

    body = JSON.parse(response.body)
    assert_equal "User not found", body["error"]
  end
  test("retun pull users pending") do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok
    operator = User.create!(
  name: "Warehouse Operator",
  email_address: "operator@example.com",
  password: "secret123",
  password_confirmation: "secret123",
  status: "pending"
)
get "/admin/users"

assert_response :ok
body = JSON.parse(response.body)
users = body["users"]
operator_json = users.find { |item| item["id"] == operator.id }
assert_not_nil operator_json
assert_equal "Warehouse Operator", operator_json["name"]
assert_equal "pending", operator_json["status"]
assert_not operator_json.key?("password_digest")
end

 test("returns first page of users") do
    User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok
    operator = User.create!(
  name: "Warehouse Operator",
  email_address: "operator@example.com",
  password: "secret123",
  password_confirmation: "secret123",
  status: "pending"
)
get "/admin/users", params: {
  page: 1,
  per_page: 2
}

assert_response :ok

body = JSON.parse(response.body)
users = body["users"]
pagination = body["pagination"]

assert_equal 2, users.length
assert_equal 1, pagination["page"]
assert_equal 2, pagination["per_page"]
assert_equal User.count, pagination["total"]
end
test "returns users filtered by pending status" do
  User.create!(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "admin",
      status: "active"
    )

    post "/session", params: {
      login: {
        email_address: "vlad@example.com",
        password: "secret123"
      }
    }

    assert_response :ok

  pending_user = User.create!(
    name: "Pending Operator",
    email_address: "operator@example.com",
    password: "secret123",
    password_confirmation: "secret123",
    status: "pending"
  )

  get "/admin/users", params: {
    status: "pending",
    page: 1,
    per_page: 20
  }

  assert_response :ok

  body = JSON.parse(response.body)
  users = body["users"]

  assert users.all? { |user| user["status"] == "pending" }
  assert_includes users.map { |user| user["id"] }, pending_user.id
  assert_equal User.pending.count, body["pagination"]["total"]
end
end
