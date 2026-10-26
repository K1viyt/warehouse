class StockMovement < ApplicationRecord
  belongs_to :product
  belongs_to :user
  validates :quantity, presence: true,
                        numericality: { greater_than: 0 }
  validates :movement_type, presence: true,
                            inclusion: { in: [ "receipt", "issue" ] }
  validates :reason, presence: true
end
