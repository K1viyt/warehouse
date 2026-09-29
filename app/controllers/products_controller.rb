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
    if product.save
      render json: product, status: :created
    else
         render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
