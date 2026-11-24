class AddAccountRecoveryAndCompanyAccess < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :credentials_version, :integer, null: false, default: 0
    add_column :users, :password_change_required, :boolean, null: false, default: false
    add_check_constraint :users, "credentials_version >= 0", name: "users_credentials_version_nonnegative"
    add_column :organizations, :code, :string
    add_index :organizations, :code, unique: true
    add_index :users, [ :organization_id, :status, :id ]

    create_table :password_recovery_requests do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :handled_by, foreign_key: { to_table: :users }
      t.integer :credentials_version, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :expires_at, null: false
      t.datetime :handled_at
      t.timestamps
      t.index :user_id, unique: true, where: "status = 'pending'", name: "one_pending_password_recovery_per_user"
      t.index [ :organization_id, :status, :id ], name: "recovery_requests_inbox"
      t.check_constraint "status IN ('pending', 'completed', 'rejected', 'superseded')", name: "recovery_request_status_allowed"
    end
    tenant_key :password_recovery_requests, :user_id
    tenant_key :password_recovery_requests, :handled_by_id

    create_table :access_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.jsonb :details, null: false, default: {}
      t.timestamps
      t.index [ :organization_id, :user_id, :created_at, :id ], name: "access_events_user_timeline"
    end
    tenant_key :access_events, :user_id
    tenant_key :access_events, :actor_id
    add_index :stock_movements, [ :organization_id, :user_id, :created_at, :id ], name: "stock_movements_user_timeline"
  end

  private

  def tenant_key(table, column)
    add_foreign_key table, :users, column: [ :organization_id, column ],
      primary_key: [ :organization_id, :id ], name: "fk_#{table}_#{column}_tenant"
  end
end
