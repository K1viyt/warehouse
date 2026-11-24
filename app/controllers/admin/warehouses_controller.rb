module Admin
  class WarehousesController < ApplicationController
    before_action :require_active_user
    before_action :require_admin

    def index
      render json: current_organization.warehouses.order(:name).as_json(only: [ :id, :name ])
    end

    def create
      warehouse = current_organization.warehouses.new(params.expect(warehouse: [ :name ]))
      authorize warehouse
      StockWarehouse.transaction do
        warehouse.save!
        current_organization.products.find_each do |product|
          warehouse.stock_balances.create!(organization: current_organization, product: product, quantity: 0)
        end
        audit(warehouse, "warehouse_created")
      end
      render json: warehouse.as_json(only: [ :id, :name ]), status: :created
    end

    def update
      warehouse = current_organization.warehouses.find(params[:id])
      authorize warehouse
      warehouse.with_lock do
        warehouse.update!(params.expect(warehouse: [ :name ]))
        audit(warehouse, "warehouse_renamed")
      end
      render json: warehouse.as_json(only: [ :id, :name ])
    end

    private

    def audit(warehouse, action)
      AccessEvent.create!(organization: current_organization, user: current_user, actor: current_user,
        action: action, details: { warehouse_id: warehouse.id, name: warehouse.name })
    end
  end
end
