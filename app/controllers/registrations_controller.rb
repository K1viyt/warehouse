class RegistrationsController < ApplicationController
  def create
    attributes =params.expect(user: [ :name, :email_address, :password, :password_confirmation ])
    user = User.new(attributes)
    if user.save
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
