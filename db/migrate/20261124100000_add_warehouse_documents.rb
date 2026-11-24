class AddWarehouseDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :stock_balances, :reserved, :decimal, precision: 12, scale: 3, default: 0, null: false
    add_check_constraint :stock_balances, "reserved >= 0 AND reserved <= quantity", name: "valid_reservation"
    create_table :warehouse_documents do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false
      t.references :warehouse, null: false
      t.bigint :source_id
      t.string :kind, null: false
      t.string :state, null: false, default: "pending"
      t.uuid :request_key, null: false
      t.text :reason, null: false
      t.timestamps
      t.index [ :user_id, :request_key ], unique: true
      t.index [ :organization_id, :id ], unique: true
      t.check_constraint "kind IN ('transfer','purchase','issue','receipt') AND state IN ('pending','approved','shipped','received','posted','cancelled','rejected')", name: "valid_document"
      t.check_constraint "(kind = 'transfer') = (source_id IS NOT NULL) AND warehouse_id IS DISTINCT FROM source_id", name: "valid_source"
    end
    create_table :warehouse_lines do |t|
      t.references :organization, null: false
      t.references :warehouse_document, null: false
      t.references :product, null: false
      t.decimal :quantity, precision: 12, scale: 3, null: false
      t.check_constraint "quantity > 0", name: "positive_line"
      t.index [ :warehouse_document_id, :product_id ], unique: true
    end
    add_reference :stock_movements, :warehouse_document
    [ [ :warehouse_documents, :users, :user_id ], [ :warehouse_documents, :warehouses, :warehouse_id ],
     [ :warehouse_documents, :warehouses, :source_id ], [ :warehouse_lines, :warehouse_documents, :warehouse_document_id ],
     [ :warehouse_lines, :products, :product_id ], [ :stock_movements, :warehouse_documents, :warehouse_document_id ] ].each do |table, target, key|
      add_foreign_key table, target, column: [ :organization_id, key ], primary_key: [ :organization_id, :id ], name: "fk_#{table}_#{key}_org"
    end
    add_index :stock_movements, [ :organization_id, :id ], unique: true
    add_reference :stock_movements, :reversal_of, index: { unique: true }
    add_foreign_key :stock_movements, :stock_movements, column: [ :organization_id, :reversal_of_id ], primary_key: [ :organization_id, :id ], name: "fk_movement_reversal_org"
    create_table :document_events do |t|
      t.references :organization, null: false
      t.references :warehouse_document, null: false
      t.references :user, null: false
      t.string :state, null: false
      t.timestamps
    end
    add_foreign_key :document_events, :warehouse_documents, column: [ :organization_id, :warehouse_document_id ], primary_key: [ :organization_id, :id ], name: "fk_document_event_document_org"
    add_foreign_key :document_events, :users, column: [ :organization_id, :user_id ], primary_key: [ :organization_id, :id ], name: "fk_document_event_user_org"
  end
end
