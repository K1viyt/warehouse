require "test_helper"
require "timeout"

class CredentialChangeConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "concurrent email and admin recovery commit exactly one password change" do
    organization = Organization.create!(name: "Recovery concurrency #{SecureRandom.hex(6)}")
    user = organization.users.create!(name: "Operator", email_address: "race-#{SecureRandom.hex(6)}@example.test",
      password: "old-password", email_verified_at: Time.current, status: "active")
    admin = organization.users.create!(name: "Admin", email_address: "race-admin-#{SecureRandom.hex(6)}@example.test",
      password: "admin-password", role: "admin", status: "active")
    item = user.password_recovery_requests.create!(organization: organization, credentials_version: 0, expires_at: 1.hour.from_now)
    token = user.generate_token_for(:account_recovery)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = [ :email, :admin ].map do |channel|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          arguments = { user: User.find(user.id), password: "#{channel}-password", password_confirmation: "#{channel}-password", expected_version: 0 }
          if channel == :email
            arguments[:token] = token
          else
            arguments.merge!(temporary: true, actor: User.find(admin.id), recovery_request: PasswordRecoveryRequest.find(item.id))
          end
          begin
            CredentialChange.call(**arguments)
            results << :success
          rescue CredentialChange::StaleRequest
            results << :stale
          rescue => error
            results << error
          end
        end
      end
    end
    Timeout.timeout(15) do
      2.times { ready.pop }
      2.times { start << true }
      threads.each(&:join)
    end
    outcomes = 2.times.map { results.pop }
    assert_equal 1, outcomes.count(:success), outcomes.inspect
    assert_equal 1, outcomes.count(:stale), outcomes.inspect
    assert_equal 1, user.reload.credentials_version
    assert_equal 1, AccessEvent.where(user: user).count
    assert_not item.reload.pending?
    assert_nil User.find_by_token_for(:account_recovery, token)
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
    if organization
      AccessEvent.where(organization: organization).delete_all
      PasswordRecoveryRequest.where(organization: organization).delete_all
      User.where(organization: organization).delete_all
      organization.reload.destroy!
    end
  end
end
