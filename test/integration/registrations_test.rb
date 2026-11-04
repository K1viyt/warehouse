require "test_helper"

class RegistrationsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  test "creates pending user" do
    assert_difference("User.count", 1) do
      post "/registrations", params: {
        user: {
          name: "Vlad",
          email_address: "vlad@example.com",
          password: "secret123",
          organization_id: organizations(:one).id,
          warehouse_id: warehouses(:one).id,
          password_confirmation: "secret123"
        }
      }
    end

    assert_response :created

    created_user = User.order(:id).last

    assert_enqueued_email_with EmailVerificationMailer, :confirmation, args: [ created_user ]

    assert_emails 1 do
      perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob)
    end

    assert_equal [ created_user.email_address ], ActionMailer::Base.deliveries.last.to

    assert created_user.pending?
    assert created_user.operator?
    assert created_user.authenticate("secret123")

    membership = created_user.warehouse_memberships.find_by!(
      warehouse_id: warehouses(:one).id
    )
    assert_equal organizations(:one).id, created_user.organization_id
    assert_equal organizations(:one).id, membership.organization_id
    assert_equal "pending", membership.status
    assert_equal "operator", membership.role
  end

  test "rejects repeated email" do
    create_user(
      name: "Vlad",
      email_address: "vlad@example.com",
      password: "secret123",
      password_confirmation: "secret123"
    )

    assert_no_difference("User.count", "WarehouseMembership.count") do
      post "/registrations", params: {
        user: {
          name: "Vlad1",
          email_address: "VLAD@EXAMPLE.COM",
          password: "secret123",
          organization_id: organizations(:one).id,
          warehouse_id: warehouses(:one).id,
          password_confirmation: "secret123"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_instance_of String, response.body

    body = JSON.parse(response.body)

    assert_instance_of Hash, body
    assert_includes body["errors"], "Email address has already been taken"
  end

  test "rejects malformed email" do
    assert_no_difference("User.count", "WarehouseMembership.count") do
      post "/registrations", params: {
        user: {
          name: "Vlad1",
          email_address: "VLAD@@EXAMPLE.COM",
          password: "secret123",
          organization_id: organizations(:one).id,
          warehouse_id: warehouses(:one).id,
          password_confirmation: "secret123"
        }
      }
    end

    assert_response :unprocessable_entity
   assert_includes response.parsed_body.fetch("errors"), "Email address is invalid"
   assert_no_enqueued_emails
  end

  test "does not allow user to assign role and status" do
    assert_difference("User.count", 1) do
      post "/registrations", params: {
        user: {
          name: "Vlad",
          email_address: "vlad@example.com",
          password: "secret123",
          password_confirmation: "secret123",
          organization_id: organizations(:one).id,
          warehouse_id: warehouses(:one).id,
          role: "admin",
          status: "active"
        }
      }
    end

    created_user = User.order(:id).last

    assert created_user.operator?
    assert created_user.pending?
    assert_response :created

    body = JSON.parse(response.body)

    assert_equal "operator", body["role"]
    assert_equal "pending", body["status"]
    assert_not body.key?("password_digest")

    membership = created_user.warehouse_memberships.find_by!(warehouse_id: warehouses(:one).id)
    assert_equal "operator", membership.role
    assert_equal "pending", membership.status
  end
    test "rejects warehouse from another organization" do
      other_organization = Organization.create!(
        name: "Другая фирма",
        legal_form: "ooo"
      )

    other_warehouse = other_organization.warehouses.create!(
    name: "Чужой склад"
    )
    assert_no_difference([ "User.count", "WarehouseMembership.count" ]) do
    post "/registrations", params: {
    user: {
      name: "Оператор",
      email_address: "wrong-warehouse@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      organization_id: organizations(:one).id,
      warehouse_id: other_warehouse.id
    }
    }
    end

  assert_response :unprocessable_entity
  end
end
