class RegistrationsController < ApplicationController
  def create
     attributes = params.expect(user: [ :name, :email_address, :password, :password_confirmation, :organization_id, :warehouse_id ])
    organization = Organization.find_by(id: attributes.delete(:organization_id))
    warehouse = organization&.warehouses&.find_by(
    id: attributes.delete(:warehouse_id)
    )
   unless warehouse
    return render json: {
    errors: [ "Выберите существующую фирму и принадлежащий ей склад" ]
  }, status: :unprocessable_entity
   end
    user = organization.users.new(attributes)
    if user.valid?
      User.transaction do
        user.save!
        user.warehouse_memberships.create!(organization: organization, warehouse: warehouse, status: "pending")
      end
      EmailVerificationMailer.confirmation(user).deliver_later
     render json: {
  id: user.id,
  name: user.name,
  email_address: user.email_address,
  role: user.role,
  status: user.status
}, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
