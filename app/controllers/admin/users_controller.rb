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
      else
        user.blocked!

        render json: user.as_json(
          only: [ :id, :name, :email_address, :role, :status, :created_at ]
        ), status: :ok
      end
    end
  end
end
