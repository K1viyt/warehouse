class ApplicationController < ActionController::Base
  include Pundit::Authorization
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "Запись не найдена" }, status: :not_found
  end
  rescue_from Pundit::NotAuthorizedError do
    render json: { error: "Доступ закрыт" }, status: :forbidden
  end
  rescue_from CredentialChange::StaleRequest do |error|
    render json: { error: error.message }, status: :conflict
  end
  rescue_from CredentialChange::InvalidProof do |error|
    render json: { error: error.message }, status: :unprocessable_entity
  end
  rescue_from ActiveRecord::RecordInvalid do |error|
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
  end

  allow_browser versions: :modern
  stale_when_importmap_changes

  private

  def current_organization
    current_user.organization
  end

  def current_user
    user = User.find_by(id: session[:user_id])
    if user && (user.blocked? || session[:credentials_version] == user.credentials_version)
      user
    else
      reset_session if session[:user_id]
      nil
    end
  end

  def require_active_user
    user = current_user

    if user.nil?
      render json: {
        error: "Authentication required"
      }, status: :unauthorized
    elsif user.password_change_required?
      render json: { error: "Сначала замените временный пароль" }, status: :forbidden
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
    elsif user.password_change_required? && !%w[passwords profiles].include?(controller_name)
      render json: { error: "Сначала замените временный пароль" }, status: :forbidden
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
