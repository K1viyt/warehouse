class ProductsController < ApplicationController
   before_action :require_active_user
  def index
    products = Product.all
    render json: products
  end

  def show
    product = Product.find(params[:id])
    render json: product
  end
  def create
    attributes = params.expect(product: [ :sku, :name, :unit ])

    product = Product.new(attributes)
    # Транзакция
    ProductCreation.call(product)
    render json: product, status: :created
  rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages },
         status: :unprocessable_entity

  rescue ActiveRecord::RecordNotUnique
    render json: { errors: [ "A product with this article number already exists." ] }, status: :conflict
  end
end
