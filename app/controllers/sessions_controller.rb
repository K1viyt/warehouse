class SessionsController < ApplicationController
  def create
    credentials = params.expect(
      login: [ :email_address, :password ]
    )

    user = User.find_by(
      email_address: credentials[:email_address]
    )

    if user && user.authenticate(credentials[:password])
      if user.blocked?
        render json: {
          error: "Your access has been blocked"
        }, status: :forbidden
      else
        reset_session
        session[:user_id] = user.id

        render json: {
          id: user.id,
          name: user.name,
          role: user.role,
          status: user.status
        }, status: :ok
      end
    else
      render json: {
        error: "Invalid email or password"
      }, status: :unauthorized
    end
  end

  def destroy
    reset_session
    head :no_content
  end
end
