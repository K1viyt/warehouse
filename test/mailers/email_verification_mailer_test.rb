require "test_helper"
require "uri"

class EmailVerificationMailerTest < ActionMailer::TestCase
  test "confirmation" do
    user = create_user(
      name: "Оператор",
      email_address: "verification@example.com",
      password: "secret123"
    )
    email = EmailVerificationMailer.confirmation(user)
    assert_equal [ user.email_address ], email.to
    assert_equal "Подтверждение почты - СЕКЦИЯ", email.subject
    assert_includes email.text_part.body.decoded, "/email_verification?token="
    assert_includes email.html_part.body.decoded, "/email_verification?token="

    text = email.text_part.body.decoded
    verification_url = text.lines.find do |line|
      line.start_with?("http")
    end
    assert_not_nil verification_url

    uri = URI.parse(verification_url.strip)
    query_params = URI.decode_www_form(uri.query).to_h
    token = query_params.fetch("token")

    found_user = User.find_by_token_for(:email_verification, token)

    assert_not_nil found_user
    assert_equal user.id, found_user.id
  end
end
