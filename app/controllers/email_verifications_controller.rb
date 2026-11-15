class EmailVerificationsController < ApplicationController
  before_action :require_authenticated_user, only: :resend
  rate_limit to: 1,
           within: 1.minute,
           by: -> { current_user.id },
           only: :resend
  def show
    @token = params[:token]
    user = User.find_by_token_for(:email_verification, @token)
    unless user
      render plain: "Ссылка недействительна или просрочена.", status: :unprocessable_entity
    end
  end
  def create
    verified = User.transaction do
      user = User.lock.find_by_token_for(:email_verification, params[:token])
      user.update!(email_verified_at: Time.current) if user
    end
    if verified
       render plain: "Почта подтверждена. Доступ к складу открывает администратор."
    else
    render plain: "Ссылка недействительна или просрочена.",
           status: :unprocessable_entity
    end
  end
  def resend
  user = current_user
    if user.email_verified?
      return render json: { error: "Почта уже подтверждена" }, status: :conflict
    end
    EmailVerificationMailer.confirmation(user).deliver_later
    head :accepted
  end
end
