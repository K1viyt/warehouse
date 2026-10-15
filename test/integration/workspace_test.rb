require "test_helper"

class WorkspaceTest < ActionDispatch::IntegrationTest
  test "serves accessible HTML shell without changing JSON endpoints" do
    get "/"
    assert_response :ok
    assert_select "html[lang=ru]"
    assert_select "meta[name=viewport]"
    assert_select "[data-controller=workspace]"
    assert_select "template form[data-turbo=false]", count: 3
    assert_select "select[name=unit] option[value='шт']", text: "шт — штуки"
    assert_select "select[name=unit] option[value='кг']", text: "кг — килограммы"

    get "/products", as: :json
    assert_response :unauthorized
    assert_equal "Authentication required", response.parsed_body["error"]
  end

  test "browser CSRF token permits login and refreshed token permits product creation" do
    with_forgery_protection do
      user = User.create!(name: "Browser Operator", email_address: "browser@example.test",
        password: "browser-password", status: "active")
      get "/"
      token = csrf_token
      post "/session", params: { login: { email_address: " BROWSER@EXAMPLE.TEST ", password: "browser-password" } },
        headers: { "X-CSRF-Token" => token }, as: :json
      assert_response :ok
      assert_equal user.id, response.parsed_body["id"]

      get "/"
      token = csrf_token
      assert_difference("Product.count", 1) do
        post "/products", params: { product: { name: "Browser Bolt", sku: "BROWSER-001", unit: "шт" } },
          headers: { "X-CSRF-Token" => token }, as: :json
      end
      assert_response :created
      id = response.parsed_body["id"]
      get "/products/#{id}", as: :json
      assert_response :ok
      assert_equal "BROWSER-001", response.parsed_body["sku"]

      delete "/session", headers: { "X-CSRF-Token" => token }, as: :json
      assert_response :no_content
      get "/me", as: :json
      assert_response :unauthorized
    end
  end

  test "browser mutations without CSRF token are rejected" do
    with_forgery_protection do
      get "/"
      assert_no_difference("User.count") do
        post "/registrations", params: { user: { name: "No Token", email_address: "no-token@example.test", password: "secret123" } }, as: :json
      end
      assert_response :unprocessable_entity
    end
  end

  test "CSRF endpoint refreshes the token after a session is reset" do
    with_forgery_protection do
      User.create!(name: "Token Operator", email_address: "token@example.test",
        password: "browser-password", status: "active")
      get "/interface/csrf", as: :json
      assert_response :ok
      assert_equal "no-store", response.headers["Cache-Control"]
      token = response.parsed_body["csrf_token"]
      post "/session", params: { login: { email_address: "token@example.test", password: "browser-password" } },
        headers: { "X-CSRF-Token" => token }, as: :json
      assert_response :ok
      get "/interface/csrf", as: :json
      token = response.parsed_body["csrf_token"]
      delete "/session", headers: { "X-CSRF-Token" => token }, as: :json
      assert_response :no_content
      get "/interface/csrf", as: :json
      token = response.parsed_body["csrf_token"]
      post "/session", params: { login: { email_address: "token@example.test", password: "browser-password" } },
        headers: { "X-CSRF-Token" => token }, as: :json
      assert_response :ok
    end
  end

  private

  def csrf_token
    css_select("meta[name=csrf-token]").first["content"]
  end

  def with_forgery_protection
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
