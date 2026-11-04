class AddOrganizationsAndWarehouses < ActiveRecord::Migration[8.1]
  def up
    create_table :organizations do |t|
      t.string :name, null: false
      # Existing demo data has no known legal form; do not invent one.
      t.string :legal_form
      t.timestamps
      t.check_constraint "length(btrim(name)) > 0", name: "organizations_name_present"
      t.check_constraint "legal_form IN ('ooo', 'ip')", name: "organizations_legal_form_allowed"
    end

    create_table :warehouses do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
      t.check_constraint "length(btrim(name)) > 0", name: "warehouses_name_present"
      t.index [ :organization_id, :name ], unique: true
      t.index [ :organization_id, :id ], unique: true
    end

    %i[users products stock_balances stock_movements].each do |table|
      add_reference table, :organization, foreign_key: true
    end
    %i[stock_balances stock_movements].each do |table|
      add_reference table, :warehouse, foreign_key: true
    end

    create_table :warehouse_memberships do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :warehouse, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "operator"
      t.string :status, null: false, default: "pending"
      t.timestamps
      t.index [ :warehouse_id, :user_id ], unique: true
      t.check_constraint "role IN ('operator', 'warehouse_manager')", name: "memberships_role_allowed"
      t.check_constraint "status IN ('pending', 'active', 'blocked')", name: "memberships_status_allowed"
    end

    # SQL only: migrations must not depend on future versions of application models.
    organization_id = select_value(<<~SQL)
      INSERT INTO organizations (name, created_at, updated_at)
      VALUES ('Исходная организация', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) RETURNING id
    SQL
    warehouse_id = select_value(<<~SQL)
      INSERT INTO warehouses (organization_id, name, created_at, updated_at)
      VALUES (#{quote(organization_id)}, 'Основной склад', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) RETURNING id
    SQL
    %i[users products stock_balances stock_movements].each do |table|
      execute "UPDATE #{quote_table_name(table)} SET organization_id = #{quote(organization_id)}"
    end
    %i[stock_balances stock_movements].each do |table|
      execute "UPDATE #{quote_table_name(table)} SET warehouse_id = #{quote(warehouse_id)}"
    end
    execute <<~SQL
      INSERT INTO warehouse_memberships
        (organization_id, warehouse_id, user_id, role, status, created_at, updated_at)
      SELECT organization_id, #{quote(warehouse_id)}, id, 'operator', status, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM users WHERE role = 'operator'
    SQL

    %i[users products stock_balances stock_movements].each do |table|
      change_column_null table, :organization_id, false
    end
    %i[stock_balances stock_movements].each do |table|
      change_column_null table, :warehouse_id, false
    end

    remove_index :products, :sku
    add_index :products, [ :organization_id, :sku ], unique: true
    add_index :products, [ :organization_id, :id ], unique: true
    add_index :users, [ :organization_id, :id ], unique: true
    remove_index :stock_balances, :product_id
    add_index :stock_balances, :product_id
    add_index :stock_balances, [ :warehouse_id, :product_id ], unique: true
    add_check_constraint :users, "role IN ('operator', 'admin')", name: "users_role_allowed"
    add_check_constraint :users, "status IN ('pending', 'active', 'blocked')", name: "users_status_allowed"

    # A simple FK verifies existence; these pairs also verify the same organization.
    %i[stock_balances stock_movements].each do |table|
      tenant_foreign_key table, :products, :product_id
      tenant_foreign_key table, :warehouses, :warehouse_id
    end
    tenant_foreign_key :stock_movements, :users, :user_id
    tenant_foreign_key :warehouse_memberships, :users, :user_id
    tenant_foreign_key :warehouse_memberships, :warehouses, :warehouse_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Multiple organizations and warehouse balances cannot safely be collapsed into the old schema. Restore a backup instead."
  end

  private

  def tenant_foreign_key(from, to, reference)
    add_foreign_key from, to,
      column: [ :organization_id, reference ], primary_key: [ :organization_id, :id ],
      name: "fk_#{from}_#{to}_organization"
  end
end
