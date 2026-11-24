class ProfilesController < ApplicationController
  before_action :require_authenticated_user
  def show
    user = current_user

    if user
      render json: {
        id: user.id,
        name: user.name,
        email_address: user.email_address,
        role: user.role,
        status: user.status,
        email_verified: user.email_verified?,
        password_change_required: user.password_change_required?,
        memberships: user.warehouse_memberships.includes(:warehouse).order(:id).map { |item|
          { id: item.id, warehouse_id: item.warehouse_id, warehouse_name: item.warehouse.name, role: item.role, status: item.status }
        },
        organization: user.organization.as_json(only: [ :id, :name ]),
        warehouses: user.active? ? user.accessible_warehouses.order(:name).as_json(only: [ :id, :name ]) : []
      }, status: :ok
    else
      render json: {
        error: "Authentication required"
      }, status: :unauthorized
    end
  end
end
