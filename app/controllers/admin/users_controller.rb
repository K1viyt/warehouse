module Admin
  class UsersController < ApplicationController
    before_action :require_active_user
    before_action :require_admin

    def pending
      users = User.pending.order(:created_at)

      render json: users.as_json(
        only: [ :id, :name, :email_address, :role, :status, :created_at ]
      ), status: :ok
    end

    def activate
      user = User.find_by(id: params[:id])

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
        user.active!

        render json: user.as_json(
          only: [ :id, :name, :email_address, :role, :status, :created_at ]
        ), status: :ok
      end
    end

    def block
      user = User.find_by(id: params[:id])

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
        user.blocked!

        render json: user.as_json(
          only: [ :id, :name, :email_address, :role, :status, :created_at ]
        ), status: :ok
      end
    end
    def unblock
      user = User.find_by(id: params[:id])
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
      user.active!

      render json: user.as_json(
    only: [ :id, :name, :email_address, :role, :status, :created_at ]
      ), status: :ok
      end
    end
   def index
  page = [ params.fetch(:page, 1).to_i, 1 ].max
  per_page = params.fetch(:per_page, 20).to_i.clamp(1, 100)

  users_scope = User.order(:id)

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
