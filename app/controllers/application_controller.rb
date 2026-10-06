class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  private

  def current_user
    User.find_by(id: session[:user_id])
  end

  def require_active_user
    user = current_user

    if user.nil?
      render json: {
        error: "Authentication required"
      }, status: :unauthorized
    elsif user.pending?
      render json: {
        error: "Account is pending activation"
      }, status: :forbidden
    elsif user.blocked?
      reset_session

      render json: {
        error: "Your access has been blocked"
      }, status: :forbidden
    end
  end

  def require_authenticated_user
    user = current_user

    if user.nil?
      render json: {
        error: "Authentication required"
      }, status: :unauthorized
    elsif user.blocked?
      reset_session

      render json: {
        error: "Your access has been blocked"
      }, status: :forbidden
    end
  end

  def require_admin
    user = current_user

    unless user.admin?
      render json: {
        error: "Administrator access required"
      }, status: :forbidden
    end
  end
end
