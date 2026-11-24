class WarehouseOperationsController < ApplicationController
  before_action :require_active_user
  rescue_from WarehouseWorkflow::Invalid do |error|
    render json: { error: error.message }, status: :unprocessable_entity
  end
  rescue_from WarehouseWorkflow::Conflict do |error|
    render json: { error: error.message }, status: :conflict
  end

  def inventory
    warehouse = current_user.accessible_warehouses.find(params[:warehouse_id])
    products = current_organization.products.where(archived_at: nil).order(:name, :id)
    balances = StockBalance.where(organization: current_organization).includes(:warehouse).group_by(&:product_id)
    render json: { warehouses: current_organization.warehouses.order(:name).as_json(only: [ :id, :name ]),
      products: products.map { |p|
        values = balances.fetch(p.id, [])
        local = values.find { |b| b.warehouse_id == warehouse.id }
        { id: p.id, sku: p.sku, name: p.name, unit: p.unit, quantity: local&.quantity || 0, reserved: local&.reserved || 0,
          available: values.to_h { |b| [ b.warehouse_id, b.quantity - b.reserved ] } }
      } }
  end

  def index
    docs = visible_documents
    warehouse = current_user.accessible_warehouses.find(params[:warehouse_id])
    docs = docs.where("warehouse_id = ? OR source_id = ?", warehouse.id, warehouse.id)
    render json: page(docs) { |d| serialize(d) }
  end

  def create
    data = params.expect(document: [ :kind, :reason, :source_id, :warehouse_id, :request_key, lines: [ [ :quantity, :product_id ] ] ])
    render json: serialize(WarehouseWorkflow.new(current_user).create(data)), status: :created
  end

  def update
    doc = visible_documents.find(params[:id])
    render json: serialize(WarehouseWorkflow.new(current_user).advance(doc, params.expect(:transition)))
  end

  def reverse
    warehouse = current_user.accessible_warehouses.find(params[:warehouse_id])
    raise Pundit::NotAuthorizedError unless StockWarehousePolicy.new(current_user, warehouse).manage?
    movement = warehouse.stock_movements.find(params[:id])
    movement.with_lock do
      product = current_organization.products.lock("FOR SHARE").find(movement.product_id)
      raise WarehouseWorkflow::Conflict, "Товар уже в архиве" if product.archived_at
      linked = WarehouseDocument.where(organization: current_organization).find_by(id: movement.warehouse_document_id)
      if movement.reversal_of_id || StockMovement.exists?(reversal_of_id: movement.id) || (linked && !%w[issue receipt].include?(linked.kind))
        raise WarehouseWorkflow::Conflict, "Это движение нельзя исправить повторно или отдельно от перемещения"
      end
      balance = warehouse.stock_balances.lock.find_by!(product_id: movement.product_id)
      direction = movement.movement_type == "receipt" ? -1 : 1
      value = balance.quantity + direction * movement.quantity
      raise WarehouseWorkflow::Conflict, "Недостаточно свободного остатка" if value < balance.reserved
      raise WarehouseWorkflow::Invalid, "Превышен максимальный остаток" if value >= 1_000_000_000
      balance.update!(quantity: value)
      warehouse.stock_movements.create!(product: movement.product, organization: current_organization,
        user: current_user, movement_type: direction == 1 ? "receipt" : "issue", quantity: movement.quantity,
        reason: params.expect(:reason), reversal_of_id: movement.id)
    end
    head :created
  end

  def journal
    warehouse = current_user.accessible_warehouses.find(params[:warehouse_id])
    rows = warehouse.stock_movements.includes(:product, :user, :reversal, :warehouse_document)
    rows = rows.where(product_id: params[:product_id]) if params[:product_id].present?
    rows = rows.where(movement_type: params[:movement_type]) if params[:movement_type].present?
    rows = rows.where(created_at: Date.iso8601(params[:from]).in_time_zone..) if params[:from].present?
    rows = rows.where(created_at: ...Date.iso8601(params[:to]).next_day.in_time_zone) if params[:to].present?
    rows = rows.where(user_id: params[:user_id]) if params[:user_id].present?
    can_manage = StockWarehousePolicy.new(current_user, warehouse).manage?
    render json: page(rows) { |m| m.as_json(only: [ :id, :quantity, :reason, :created_at, :movement_type, :warehouse_document_id ]).merge(product: m.product.name, sku: m.product.sku, unit: m.product.unit, operator: m.user.name, operator_id: m.user_id, reversal_of: m.reversal_of_id, reversible: can_manage && !m.reversal_of_id && !m.reversal && !%w[transfer purchase].include?(m.warehouse_document&.kind)) }
  rescue Date::Error
    render json: { error: "Проверьте даты периода" }, status: :unprocessable_entity
  end

  private

  def visible_documents
    ids = current_user.accessible_warehouses.select(:id)
    all = WarehouseDocument.where(organization: current_organization)
    all.where(warehouse_id: ids).or(all.where(source_id: ids)).includes(:warehouse, :source, :user, warehouse_lines: :product, document_events: :user)
  end

  def page(scope)
    scope = scope.where("id < ?", params[:before].to_i) if params[:before].present?
    rows = scope.order(id: :desc).limit(26).to_a
    { rows: rows.first(25).map { |r| yield r }, next_cursor: rows.size > 25 ? rows[24].id : nil }
  end

  def serialize(doc)
    { id: doc.id, kind: doc.kind, state: doc.state, reason: doc.reason, destination: doc.warehouse.name,
      source: doc.source&.name, actions: doc.actions(current_user), author: doc.user.name,
      lines: doc.warehouse_lines.map { |l| { name: l.product.name, sku: l.product.sku, quantity: l.quantity, unit: l.product.unit } },
      events: doc.document_events.sort_by(&:id).map { |e| { state: e.state, at: e.created_at, actor: e.user.name } } }
  end
end
