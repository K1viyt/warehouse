class EmailVerificationMailer < ApplicationMailer
  def confirmation(user)
    @user = user
    token = @user.generate_token_for(:email_verification)
    @verification_url = email_verification_url(token: token)
    mail(
      to: @user.email_address,
      subject: "Подтверждение почты - СЕКЦИЯ"
    )
  end
end
