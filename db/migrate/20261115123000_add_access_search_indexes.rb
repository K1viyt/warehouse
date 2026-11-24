class AddAccessSearchIndexes < ActiveRecord::Migration[8.1]
  def up
    add_index :access_events, [ :organization_id, :created_at, :id ], name: "access_events_company_timeline"
    execute "CREATE INDEX users_company_name_prefix ON users (organization_id, lower(name) text_pattern_ops)"
  end

  def down
    remove_index :access_events, name: "access_events_company_timeline"
    remove_index :users, name: "users_company_name_prefix"
  end
end
