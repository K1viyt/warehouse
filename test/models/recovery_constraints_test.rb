require "test_helper"

class RecoveryConstraintsTest < ActiveSupport::TestCase
  test "database rejects duplicate pending recovery and cross tenant user" do
    user = create_user(name: "Operator", email_address: "constraints@example.test", password: "secret123")
    attributes = { organization_id: user.organization_id, user_id: user.id,
      credentials_version: 0, status: "pending", expires_at: 1.hour.from_now,
      created_at: Time.current, updated_at: Time.current }
    PasswordRecoveryRequest.insert_all!([ attributes ])
    assert_raises(ActiveRecord::RecordNotUnique) do
      PasswordRecoveryRequest.transaction(requires_new: true) { PasswordRecoveryRequest.insert_all!([ attributes ]) }
    end
    foreign = Organization.create!(name: "Other")
    assert_raises(ActiveRecord::InvalidForeignKey) do
      PasswordRecoveryRequest.transaction(requires_new: true) do
        PasswordRecoveryRequest.insert_all!([ attributes.merge(organization_id: foreign.id, status: "rejected") ])
      end
    end
  end
end
