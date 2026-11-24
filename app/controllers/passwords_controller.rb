class PasswordsController < ApplicationController
  before_action :require_authenticated_user, only: :update
  before_action :disable_caching
  rate_limit to: 10, within: 10.minutes, only: [ :update, :reset ]

  def update
    attributes = params.expect(password_change: [ :current_password, :password, :password_confirmation ])
    user = current_user
    CredentialChange.call(user: user, expected_version: user.credentials_version,
      current_password: attributes[:current_password], password: attributes[:password],
      password_confirmation: attributes[:password_confirmation])
    reset_session
    render json: { message: "Пароль изменён. Войдите заново." }
  end

  def reset
    attributes = params.expect(password_reset: [ :token, :password, :password_confirmation ])
    user = User.find_by_token_for(:account_recovery, attributes[:token])
    raise CredentialChange::InvalidProof, "Ссылка недействительна или просрочена." unless user
    CredentialChange.call(user: user, expected_version: user.credentials_version, token: attributes[:token],
      password: attributes[:password], password_confirmation: attributes[:password_confirmation])
    reset_session
    render json: { message: "Пароль изменён. Войдите заново." }
  end

  private

  def disable_caching
    response.headers["Cache-Control"] = "no-store"
  end
end
