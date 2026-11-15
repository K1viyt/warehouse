# Preview all emails at http://localhost:3000/rails/mailers/email_verification_mailer
class EmailVerificationMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/email_verification_mailer/confirmation
  def confirmation
    EmailVerificationMailer.confirmation
  end
end
