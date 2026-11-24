require "test_helper"

class PasswordRecoveryTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    Rails.cache.clear
    @user = create_user(name: "Сотрудник", email_address: "recover@example.test", password: "old-password", status: "active")
    @admin = create_user(name: "Админ", email_address: "admin-recovery@example.test", password: "admin-password", status: "active", role: "admin")
  end

  test "public responses do not reveal account or verification state" do
    responses = []
    [ @user.email_address, "absent@example.test" ].each do |email|
      perform_enqueued_jobs do
        assert_no_difference("ActionMailer::Base.deliveries.size") do
          post "/password_recovery", params: { recovery: { email_address: email, channel: "email" } }
        end
      end
      assert_response :accepted
      responses << response.parsed_body
    end
    assert_equal responses.first, responses.last
  end

  test "verified email receives a working single use link without activating account" do
    @user.update!(status: "pending", email_verified_at: Time.current)
    perform_enqueued_jobs do
      assert_difference("ActionMailer::Base.deliveries.size", 1) do
        post "/password_recovery", params: { recovery: { email_address: " RECOVER@EXAMPLE.TEST ", channel: "email" } }
      end
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ @user.email_address ], mail.to
    url = mail.text_part.body.decoded.match(%r{http[^\s]+})[0]
    token = Rack::Utils.parse_query(URI(url).query).fetch("token")
    get "/password_reset", params: { token: token }
    assert_response :ok
    assert_not @user.reload.authenticate("new-password")
    post_reset(token)
    assert_response :ok
    assert @user.reload.authenticate("new-password")
    assert @user.pending?
    post_reset(token)
    assert_response :unprocessable_entity
  end

  test "invalid expired and wrong purpose tokens cannot change password" do
    @user.update!(email_verified_at: Time.current)
    token = @user.generate_token_for(:account_recovery)
    travel 16.minutes do
      post_reset(token)
      assert_response :unprocessable_entity
    end
    post_reset(@user.generate_token_for(:email_verification))
    assert_response :unprocessable_entity
    post_reset("bad-token")
    assert_response :unprocessable_entity
    assert @user.reload.authenticate("old-password")
  end

  test "admin request is deduplicated and closes when email wins" do
    @user.update!(email_verified_at: Time.current)
    2.times { request_admin }
    assert_equal 1, @user.password_recovery_requests.pending.count
    item = @user.password_recovery_requests.first
    token = @user.generate_token_for(:account_recovery)
    post_reset(token)
    assert_response :ok
    assert item.reload.superseded?
    sign_in(@admin, "admin-password")
    approve(item)
    assert_response :conflict
    assert @user.reload.authenticate("new-password")
  end

  test "admin wins invalidates old link and forces temporary password change" do
    @user.update!(email_verified_at: Time.current)
    token = @user.generate_token_for(:account_recovery)
    request_admin
    item = @user.password_recovery_requests.first
    sign_in(@admin, "admin-password")
    approve(item)
    assert_response :ok
    assert item.reload.completed?
    assert @user.reload.password_change_required?
    post_reset(token)
    assert_response :unprocessable_entity
    sign_in(@user, "temporary-password")
    get "/products"
    assert_response :forbidden
    get "/me"
    assert_response :ok
    assert response.parsed_body.fetch("password_change_required")
    patch "/password", params: { password_change: { current_password: "temporary-password", password: "personal-password", password_confirmation: "personal-password" } }
    assert_response :ok
    assert_not @user.reload.password_change_required?
    get "/me"
    assert_response :unauthorized
    sign_in(@user, "personal-password")
    get "/products"
    assert_response :ok
  end

  test "password reset revokes another session and pending queued recovery" do
    @user.update!(email_verified_at: Time.current)
    other_session = open_session
    other_session.post "/session", params: { login: { email_address: @user.email_address, password: "old-password" } }
    version = @user.credentials_version
    post_reset(@user.generate_token_for(:account_recovery))
    assert_response :ok
    other_session.get "/me"
    assert_equal 401, other_session.response.status
    assert_no_difference("PasswordRecoveryRequest.count") do
      PasswordRecoveryJob.perform_now(@user.email_address, "admin", version)
    end
  end

  test "password failure rolls back version request and audit" do
    request_admin
    item = @user.password_recovery_requests.first
    sign_in(@admin, "admin-password")
    assert_no_difference("AccessEvent.count") do
      patch "/admin/password_recovery_requests/#{item.id}", params: { recovery: { identity_confirmed: true, password: "abc", password_confirmation: "abc" } }, as: :json
    end
    assert_response :unprocessable_entity
    assert_equal 0, @user.reload.credentials_version
    assert item.reload.pending?
    assert @user.authenticate("old-password")
  end

  test "identity confirmation and own company scope are required" do
    request_admin
    item = @user.password_recovery_requests.first
    sign_in(@admin, "admin-password")
    patch "/admin/password_recovery_requests/#{item.id}", params: { recovery: { password: "temporary-password", password_confirmation: "temporary-password" } }
    assert_response :unprocessable_entity
    foreign = Organization.create!(name: "Другая фирма")
    admin = foreign.users.create!(name: "Чужой админ", email_address: "foreign-admin@example.test", password: "admin-password", role: "admin", status: "active")
    sign_in(admin, "admin-password")
    approve(item)
    assert_response :not_found
    get "/admin/password_recovery_requests"
    assert_empty response.parsed_body.fetch("requests")
    assert @user.reload.authenticate("old-password")
  end

  test "operator cannot recover coworkers and admin cannot reset another admin" do
    request_admin
    sign_in(@user, "old-password")
    approve(@user.password_recovery_requests.first)
    assert_response :forbidden
    item = @admin.password_recovery_requests.create!(organization: @admin.organization, credentials_version: 0, expires_at: 1.hour.from_now)
    sign_in(@admin, "admin-password")
    approve(item)
    assert_response :forbidden
  end

  test "expired admin request cannot be approved and repeat creates fresh request" do
    request_admin
    item = @user.password_recovery_requests.first
    travel 2.days do
      sign_in(@admin, "admin-password")
      approve(item)
      assert_response :conflict
      request_admin
      assert item.reload.superseded?
      assert_equal 1, @user.password_recovery_requests.pending.count
    end
  end

  test "reset keeps blocked status and cannot grant warehouse access" do
    @user.update!(status: "blocked", email_verified_at: Time.current)
    post_reset(@user.generate_token_for(:account_recovery))
    assert_response :ok
    assert @user.reload.blocked?
    post "/session", params: { login: { email_address: @user.email_address, password: "new-password" } }
    assert_response :forbidden
  end

  test "profile requires current password and rejects blank new password" do
    sign_in(@user, "old-password")
    patch "/password", params: { password_change: { current_password: "incorrect", password: "new-password", password_confirmation: "new-password" } }
    assert_response :unprocessable_entity
    patch "/password", params: { password_change: { current_password: "old-password", password: "", password_confirmation: "" } }
    assert_response :unprocessable_entity
    assert_equal 0, @user.reload.credentials_version
  end

  test "email requests are limited per address without exposing account existence" do
    @user.update!(email_verified_at: Time.current)
    assert_enqueued_jobs 3, only: PasswordRecoveryJob do
      4.times do
        post "/password_recovery", params: { recovery: { email_address: @user.email_address, channel: "email" } }
        assert_response :accepted
      end
    end
  end

  private

  def request_admin
    perform_enqueued_jobs do
      post "/password_recovery", params: { recovery: { email_address: @user.email_address, channel: "admin" } }
    end
    assert_response :accepted
  end

  def sign_in(user, password)
    post "/session", params: { login: { email_address: user.email_address, password: password } }
    assert_response :ok
  end

  def post_reset(token)
    post "/password_reset", params: { password_reset: { token: token, password: "new-password", password_confirmation: "new-password" } }
  end

  def approve(item)
    patch "/admin/password_recovery_requests/#{item.id}", params: { recovery: { identity_confirmed: true, password: "temporary-password", password_confirmation: "temporary-password" } }, as: :json
  end
end
