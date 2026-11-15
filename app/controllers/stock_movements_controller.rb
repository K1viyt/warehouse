class StockMovementsController < ApplicationController
   before_action :require_active_user
  def create
    attributes  = params.expect(stock_issue: [ :product_id, :amount, :reason ])
    user = current_user
    warehouse = user.accessible_warehouses.find(params[:warehouse_id])
    product = current_organization.products.find(attributes[:product_id])
    movement = StockIssue.call(
      product: product,
      warehouse: warehouse,
      amount: attributes[:amount],
      reason: attributes[:reason],
      user: user
    )
    render json: movement, status: :created

  rescue ActiveRecord::RecordNotFound
    render json: { error: "Склад или товар не найден" }, status: :not_found

  rescue StockIssue::AccessDenied
    render json: { error: "Доступ к складу закрыт" }, status: :forbidden
  rescue StockIssue::InsufficientStock => error
     render json: { error: error.message }, status: :conflict
  rescue StockIssue::InvalidAmount=>error
    render json: { error: error.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => error
    render json: { errors: error.record.errors.full_messages },
      status: :unprocessable_entity
  end
end
