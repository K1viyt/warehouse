namespace :warehouse do
  desc "Create missing stock balances for each warehouse within its organization"
  task backfill_stock_balances: :environment do
    StockWarehouse.find_each do |warehouse|
      StockBalanceBackfill.call(warehouse: warehouse)
    end
  end
end
