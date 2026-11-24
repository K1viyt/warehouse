module Admin
  class WarehouseMembershipsController < ApplicationController
    before_action :require_active_user
    before_action :require_admin

    def index
      user = current_organization.users.find(params[:user_id])
      render json: user.warehouse_memberships.includes(:warehouse).order(:id).map { |item| serialize(item) }
    end

    def create
      attributes = params.expect(membership: [ :user_id, :warehouse_id, :role, :status ])
      user = current_organization.users.find(attributes.delete(:user_id))
      warehouse = current_organization.warehouses.find(attributes.delete(:warehouse_id))
      item = user.warehouse_memberships.new(organization: current_organization, warehouse: warehouse)
      MembershipChange.call(actor: current_user, membership: item, attributes: attributes.to_h.symbolize_keys)
      render json: serialize(item), status: :created
    rescue ActiveRecord::RecordNotUnique
      render json: { error: "Назначение на этот склад уже существует" }, status: :conflict
    end

    def update
      item = current_organization.warehouse_memberships.find(params[:id])
      attributes = params.expect(membership: [ :role, :status ])
      MembershipChange.call(actor: current_user, membership: item, attributes: attributes.to_h.symbolize_keys)
      render json: serialize(item)
    end

    private

    def serialize(item)
      item.as_json(only: [ :id, :user_id, :warehouse_id, :role, :status ]).merge(warehouse_name: item.warehouse.name)
    end
  end
end
