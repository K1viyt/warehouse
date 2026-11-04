class ProductsController < ApplicationController
   before_action :require_active_user
  def index
    products = current_organization.products
    render json: products
  end

  def show
    product = current_organization.products.find_by(id: params[:id])
    return render json: { error: "Product not found" }, status: :not_found unless product
    render json: product
  end
  def create
    attributes = params.expect(product: [ :sku, :name, :unit ])

    product = current_organization.products.new(attributes)
    warehouses = current_user.accessible_warehouses
    warehouse = if params[:warehouse_id].present?
      warehouses.find_by(id: params[:warehouse_id])
    elsif warehouses.limit(2).count == 1
      warehouses.first
    end
    unless warehouse
      return render json: { errors: [ "Select an accessible warehouse" ] }, status: :unprocessable_entity
    end
    # Транзакция
    ProductCreation.call(product, warehouse: warehouse)
    render json: product, status: :created
  rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages },
         status: :unprocessable_entity

  rescue ActiveRecord::RecordNotUnique
    render json: { errors: [ "A product with this article number already exists." ] }, status: :conflict
  end
end
