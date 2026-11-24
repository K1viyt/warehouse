module Admin
  class PasswordRecoveryRequestsController < ApplicationController
    before_action :require_active_user
    before_action :require_admin
    before_action -> { response.headers["Cache-Control"] = "no-store" }

    def index
      requests = current_organization.password_recovery_requests.pending.where("expires_at > ?", Time.current)
      page = [ params.fetch(:page, 1).to_i, 1 ].max
      total = requests.count
      render json: { requests: requests.includes(:user).order(:id).offset((page - 1) * 20).limit(20).map { |item|
        { id: item.id, created_at: item.created_at, expires_at: item.expires_at,
          user: item.user.as_json(only: [ :id, :name, :email_address ]) }
      }, pagination: { page: page, total_pages: (total / 20.0).ceil } }
    end

    def update
      item = current_organization.password_recovery_requests.find(params[:id])
      attributes = params.expect(recovery: [ :password, :password_confirmation, :identity_confirmed ])
      unless attributes[:identity_confirmed] == true
        return render json: { error: "Подтвердите личность сотрудника по известному рабочему контакту." }, status: :unprocessable_entity
      end
      CredentialChange.call(user: item.user, actor: current_user, expected_version: item.credentials_version,
        recovery_request: item, temporary: true, password: attributes[:password],
        password_confirmation: attributes[:password_confirmation])
      render json: { message: "Временный пароль установлен. Передайте его сотруднику лично или по проверенному каналу." }
    end

    def destroy
      item = current_organization.password_recovery_requests.find(params[:id])
      item.user.with_lock do
        Pundit.authorize(current_user, item.user, :reset_password?)
        item.reload
        raise CredentialChange::StaleRequest, "Заявка уже обработана или устарела." unless item.actionable?
        item.update!(status: "rejected", handled_by: current_user, handled_at: Time.current)
        AccessEvent.create!(organization: current_organization, user: item.user, actor: current_user, action: "recovery_rejected")
      end
      head :no_content
    end
  end
end
