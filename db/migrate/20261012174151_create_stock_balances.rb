class CreateStockBalances < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_balances do |t|
      t.references :product, null: false, foreign_key: true, index: { unique: true }
      t.decimal :quantity, precision: 12, scale: 3, null: false, default: 0
      t.check_constraint "quantity >= 0", name: "stock_balances_quantity_nonnegative"
      t.timestamps
    end
  end
end
