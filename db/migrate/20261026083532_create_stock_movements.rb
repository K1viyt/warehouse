class CreateStockMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_movements do |t|
      t.references :product, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :quantity, precision: 12, scale: 3, null: false
     t.string :movement_type, null: false
      t.text :reason, null: false
      t.check_constraint "quantity > 0",
                   name: "stock_movements_quantity_positive"
      t.check_constraint "movement_type IN ('receipt', 'issue')",
                   name: "stock_movements_type_allowed"
      t.timestamps
    end
  end
end
