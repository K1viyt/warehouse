class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :sku
      t.string :name
      t.string :unit
      t.datetime :archived_at

      t.timestamps
    end
  end
end
