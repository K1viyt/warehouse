module Admin
  class UsersController < ApplicationController
    before_action :require_active_user
    before_action :require_admin

    def pending
      users = current_organization.users.pending.order(:created_at)

      render json: users.as_json(
        only: [ :id, :name, :email_address, :role, :status, :created_at ]
      ), status: :ok
    end

    def activate
      user = current_organization.users.find_by(id: params[:id])

      if user.nil?
        render json: {
          error: "User not found"
        }, status: :not_found
      elsif user.active?
        render json: {
          error: "User is already active"
        }, status: :conflict
      elsif user.blocked?
        render json: {
          error: "Blocked user must be unblocked first"
        }, status: :conflict
      else
        user.with_lock do
          user.active!
          pending = user.warehouse_memberships.pending
          membership = if params[:membership_id].present?
            pending.find(params[:membership_id])
          elsif pending.count == 1
            pending.first
          end
          raise CredentialChange::StaleRequest, "Выберите конкретное назначение на склад." unless membership
          MembershipChange.call(actor: current_user, membership: membership, attributes: { status: "active" })
        end

        render json: user.as_json(
          only: [ :id, :name, :email_address, :role, :status, :created_at ]
        ), status: :ok
      end
    end

    def block
      user = current_organization.users.find_by(id: params[:id])

      if user.nil?
        render json: {
          error: "User not found"
        }, status: :not_found
      elsif user.blocked?
        render json: {
          error: "User is already blocked"
        }, status: :conflict
      elsif user.admin?
        render json: {
          error: "Administrator accounts cannot be blocked"
        }, status: :conflict
      elsif user.pending?
        render json: {
        error: "Pending user must be activated first"
      }, status: :conflict
      else
        user.with_lock do
          user.blocked!
          AccessEvent.create!(organization: current_organization, user: user, actor: current_user, action: "user_blocked")
        end

        render json: user.as_json(
          only: [ :id, :name, :email_address, :role, :status, :created_at ]
        ), status: :ok
      end
    end
    def unblock
      user = current_organization.users.find_by(id: params[:id])
      if user.nil?
        render json: { error: "User not found" }, status: :not_found
      elsif user.active?
        render json: {
      error: "User is already active"
      }, status: :conflict
      elsif user.pending?
        render json: {
      error: "Pending user must be activated first"
      }, status: :conflict
      else
      user.with_lock do
        user.active!
        AccessEvent.create!(organization: current_organization, user: user, actor: current_user, action: "user_unblocked")
      end

      render json: user.as_json(
    only: [ :id, :name, :email_address, :role, :status, :created_at ]
      ), status: :ok
      end
    end
   def index
  page = [ params.fetch(:page, 1).to_i, 1 ].max
  per_page = params.fetch(:per_page, 20).to_i.clamp(1, 100)

  users_scope = current_organization.users.order(:id)
  if params[:q].present?
    query = params[:q].to_s.strip
    if query.include?("@")
      users_scope = users_scope.where(email_address: query.downcase)
    elsif query.match?(/\A[0-9]+\z/)
      users_scope = users_scope.where(id: query.to_i)
    else
      users_scope = users_scope.where("lower(name) LIKE ?", "#{User.sanitize_sql_like(query.downcase)}%")
    end
  end

  if params[:status].present?
    users_scope = users_scope.where(status: params[:status])
  end

  total = users_scope.count
  offset = (page - 1) * per_page
  users = users_scope.offset(offset).limit(per_page)

  render json: {
    users: users.as_json(
      only: [ :id, :name, :email_address, :role, :status, :created_at ]
    ),
    pagination: {
      page: page,
      per_page: per_page,
      total: total,
      total_pages: (total.to_f / per_page).ceil
    }
  }, status: :ok
    end
  end
end
