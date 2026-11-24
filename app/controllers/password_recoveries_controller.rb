class PasswordRecoveriesController < ApplicationController
  MESSAGE = "Если восстановление доступно, письмо будет отправлено или заявка передана администратору."
  rate_limit to: 10, within: 10.minutes, name: "ip", only: :create
  rate_limit to: 3, within: 15.minutes, name: "email", only: :create,
    by: -> { Digest::SHA256.hexdigest((params[:recovery].is_a?(ActionController::Parameters) ? params[:recovery][:email_address] : nil).to_s.strip.downcase) },
    with: -> { render json: { message: MESSAGE }, status: :accepted }

  def create
    attributes = params.expect(recovery: [ :email_address, :channel ])
    unless %w[email admin].include?(attributes[:channel]) && attributes[:email_address].is_a?(String)
      return render json: { error: "Укажите почту и способ восстановления." }, status: :unprocessable_entity
    end
    email = attributes[:email_address].strip.downcase
    user = User.find_by(email_address: email)
    PasswordRecoveryJob.perform_later(email, attributes[:channel], user&.credentials_version)
    render json: { message: MESSAGE }, status: :accepted
  end
end
