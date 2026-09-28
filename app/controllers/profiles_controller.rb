class ProfilesController < ApplicationController
  def show
    user = current_user

    if user
      render json: {
        id: user.id,
        name: user.name,
        email_address: user.email_address,
        role: user.role,
        status: user.status
      }, status: :ok
    else
      render json: {
        error: "Authentication required"
      }, status: :unauthorized
    end
  end
end
