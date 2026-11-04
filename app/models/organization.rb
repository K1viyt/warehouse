class Organization < ApplicationRecord
  has_many :warehouses, class_name: "StockWarehouse", dependent: :restrict_with_error
  has_many :users, dependent: :restrict_with_error
  has_many :products, dependent: :restrict_with_error
  has_many :warehouse_memberships, dependent: :restrict_with_error

  validates :name, presence: true
  validates :legal_form, inclusion: { in: %w[ooo ip] }, allow_nil: true
end
