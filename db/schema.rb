# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_30_152209) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "legal_form"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "legal_form::text = ANY (ARRAY['ooo'::character varying, 'ip'::character varying]::text[])", name: "organizations_legal_form_allowed"
    t.check_constraint "length(btrim(name::text)) > 0", name: "organizations_name_present"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "organization_id", null: false
    t.string "sku"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "id"], name: "index_products_on_organization_id_and_id", unique: true
    t.index ["organization_id", "sku"], name: "index_products_on_organization_id_and_sku", unique: true
    t.index ["organization_id"], name: "index_products_on_organization_id"
  end

  create_table "stock_balances", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", precision: 12, scale: 3, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.bigint "warehouse_id", null: false
    t.index ["organization_id"], name: "index_stock_balances_on_organization_id"
    t.index ["product_id"], name: "index_stock_balances_on_product_id"
    t.index ["warehouse_id", "product_id"], name: "index_stock_balances_on_warehouse_id_and_product_id", unique: true
    t.index ["warehouse_id"], name: "index_stock_balances_on_warehouse_id"
    t.check_constraint "quantity >= 0::numeric", name: "stock_balances_quantity_nonnegative"
  end

  create_table "stock_movements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "movement_type", null: false
    t.bigint "organization_id", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity", precision: 12, scale: 3, null: false
    t.text "reason", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "warehouse_id", null: false
    t.index ["organization_id"], name: "index_stock_movements_on_organization_id"
    t.index ["product_id"], name: "index_stock_movements_on_product_id"
    t.index ["user_id"], name: "index_stock_movements_on_user_id"
    t.index ["warehouse_id"], name: "index_stock_movements_on_warehouse_id"
    t.check_constraint "movement_type::text = ANY (ARRAY['receipt'::character varying, 'issue'::character varying]::text[])", name: "stock_movements_type_allowed"
    t.check_constraint "quantity > 0::numeric", name: "stock_movements_quantity_positive"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "email_verified_at"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "password_digest", null: false
    t.string "role", default: "operator", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["organization_id", "id"], name: "index_users_on_organization_id_and_id", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.check_constraint "role::text = ANY (ARRAY['operator'::character varying, 'admin'::character varying]::text[])", name: "users_role_allowed"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'active'::character varying, 'blocked'::character varying]::text[])", name: "users_status_allowed"
  end

  create_table "warehouse_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.string "role", default: "operator", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "warehouse_id", null: false
    t.index ["organization_id"], name: "index_warehouse_memberships_on_organization_id"
    t.index ["user_id"], name: "index_warehouse_memberships_on_user_id"
    t.index ["warehouse_id", "user_id"], name: "index_warehouse_memberships_on_warehouse_id_and_user_id", unique: true
    t.index ["warehouse_id"], name: "index_warehouse_memberships_on_warehouse_id"
    t.check_constraint "role::text = ANY (ARRAY['operator'::character varying, 'warehouse_manager'::character varying]::text[])", name: "memberships_role_allowed"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'active'::character varying, 'blocked'::character varying]::text[])", name: "memberships_status_allowed"
  end

  create_table "warehouses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "id"], name: "index_warehouses_on_organization_id_and_id", unique: true
    t.index ["organization_id", "name"], name: "index_warehouses_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_warehouses_on_organization_id"
    t.check_constraint "length(btrim(name::text)) > 0", name: "warehouses_name_present"
  end

  add_foreign_key "products", "organizations"
  add_foreign_key "stock_balances", "organizations"
  add_foreign_key "stock_balances", "products"
  add_foreign_key "stock_balances", "products", column: ["organization_id", "product_id"], primary_key: ["organization_id", "id"], name: "fk_stock_balances_products_organization"
  add_foreign_key "stock_balances", "warehouses"
  add_foreign_key "stock_balances", "warehouses", column: ["organization_id", "warehouse_id"], primary_key: ["organization_id", "id"], name: "fk_stock_balances_warehouses_organization"
  add_foreign_key "stock_movements", "organizations"
  add_foreign_key "stock_movements", "products"
  add_foreign_key "stock_movements", "products", column: ["organization_id", "product_id"], primary_key: ["organization_id", "id"], name: "fk_stock_movements_products_organization"
  add_foreign_key "stock_movements", "users"
  add_foreign_key "stock_movements", "users", column: ["organization_id", "user_id"], primary_key: ["organization_id", "id"], name: "fk_stock_movements_users_organization"
  add_foreign_key "stock_movements", "warehouses"
  add_foreign_key "stock_movements", "warehouses", column: ["organization_id", "warehouse_id"], primary_key: ["organization_id", "id"], name: "fk_stock_movements_warehouses_organization"
  add_foreign_key "users", "organizations"
  add_foreign_key "warehouse_memberships", "organizations"
  add_foreign_key "warehouse_memberships", "users"
  add_foreign_key "warehouse_memberships", "users", column: ["organization_id", "user_id"], primary_key: ["organization_id", "id"], name: "fk_warehouse_memberships_users_organization"
  add_foreign_key "warehouse_memberships", "warehouses"
  add_foreign_key "warehouse_memberships", "warehouses", column: ["organization_id", "warehouse_id"], primary_key: ["organization_id", "id"], name: "fk_warehouse_memberships_warehouses_organization"
  add_foreign_key "warehouses", "organizations"
end
