class PasswordRecoveryJob < ApplicationJob
  queue_as :default
  retry_on Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, wait: :polynomially_longer, attempts: 5

  def perform(email, channel, expected_version)
    user = User.find_by(email_address: email)
    return unless user && expected_version
    token = nil
    user.with_lock do
      return unless user.credentials_version == expected_version
      if channel == "email"
        return unless user.email_verified?
        token = user.generate_token_for(:account_recovery)
      else
        return if user.admin?
        user.password_recovery_requests.pending.where("expires_at <= ? OR credentials_version <> ?", Time.current, user.credentials_version)
          .update_all(status: "superseded", handled_at: Time.current, updated_at: Time.current)
        unless user.password_recovery_requests.pending.exists?
          user.password_recovery_requests.create!(organization: user.organization,
            credentials_version: user.credentials_version, expires_at: 1.day.from_now)
        end
      end
    end
    # Bind the delivered link to the credentials checked under this lock.
    PasswordRecoveryMailer.reset_link(user, token).deliver_now if token
  end
end
