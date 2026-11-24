class WarehouseDocument < ApplicationRecord
  belongs_to :organization
  belongs_to :warehouse, class_name: "StockWarehouse"
  belongs_to :source, class_name: "StockWarehouse", optional: true
  belongs_to :user
  has_many :warehouse_lines
  has_many :document_events
  validates :reason, presence: true, length: { maximum: 500 }

  def actions(actor)
    return [] unless actor.active? && actor.organization_id == organization_id && !actor.password_change_required?
    source_manager = source && StockWarehousePolicy.new(actor, source).manage?
    destination_manager = StockWarehousePolicy.new(actor, warehouse).manage?
    approver = kind == "transfer" ? source_manager : actor.admin?
    choices = []
    choices += %w[approve reject] if state == "pending" && approver && actor.id != user_id
    choices << "cancel" if %w[pending approved].include?(state) && (actor.id == user_id || approver)
    choices << "ship" if state == "approved" && source_manager
    choices << "receive" if destination_manager && (state == "shipped" || (kind == "purchase" && state == "approved"))
    choices
  end
end
