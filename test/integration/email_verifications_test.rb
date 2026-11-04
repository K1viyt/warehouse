require "test_helper"

class EmailVerificationsTest < ActionDispatch::IntegrationTest
  test "confirms email only after submitting the form" do
    user = create_user(name: "Оператор",
      email_address: "verification@example.com",
      password: "secret123",
      status: "pending")

      token = user.generate_token_for(:email_verification)
      get email_verification_path, params: { token: token }

      assert_response :ok

      assert_nil user.reload.email_verified_at

      post email_verification_path, params: { token: token }

      assert_response :ok
      assert user.reload.email_verified?
      assert user.pending?

      post email_verification_path, params: { token: token }

      assert_response :unprocessable_entity
  end
  test "resends verification email for a signed-in pending user" do
    user = create_user(
    name: "Оператор",
    email_address: "resend@example.com",
    password: "secret123",
    status: "pending"
    )
    post "/session", params: { login: { email_address: user.email_address, password: "secret123" } }
    assert_response :ok

    assert_enqueued_email_with EmailVerificationMailer, :confirmation, args: [ user ] do
      post "/email_verification/resend"
    end
    assert_response :accepted

    assert_no_enqueued_emails do
      post "/email_verification/resend"
    end

    assert_response :too_many_requests
  end
  test "conflict to verified email" do
    user = create_user(
    name: "Оператор",
    email_address: "resend@example.com",
    password: "secret123",
    status: "pending"
    )
    post "/session", params: { login: { email_address: user.email_address, password: "secret123" } }
    assert_response :ok

     user.update!(email_verified_at: Time.current)

    assert_no_enqueued_emails do
      post "/email_verification/resend"
    end

    assert_response :conflict
  end
end
