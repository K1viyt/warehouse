namespace :warehouse do
  desc "Create missing stock balances"
  task backfill_stock_balances: :environment do
    StockBalanceBackfill.call
  end
end
