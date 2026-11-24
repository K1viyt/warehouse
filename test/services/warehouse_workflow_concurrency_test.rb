require "test_helper"
require "timeout"

class WarehouseWorkflowConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "competing operators cannot both issue the last seven pieces" do
    company = Organization.create!(name: "Параллельный склад")
    site = company.warehouses.create!(name: "Склад")
    product = company.products.create!(name: "Шайба", unit: "шт", sku: "RACE")
    balance = site.stock_balances.create!(organization: company, product: product, quantity: 10)
    operators = 2.times.map do |i|
      company.users.create!(name: "Оператор", email_address: "race-#{SecureRandom.uuid}@example.test",
        status: "active", role: "admin", password: "test-race-#{i}")
    end
    ready = Queue.new
    start = Queue.new
    threads = operators.map do |operator|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          service = WarehouseWorkflow.new(User.find(operator.id))
          data = { request_key: SecureRandom.uuid, warehouse_id: site.id, kind: "issue", reason: "Монтаж",
            lines: [ { product_id: product.id, quantity: 7 } ] }
          ready << true
          start.pop
          begin
            service.create(data)
            :posted
          rescue WarehouseWorkflow::Conflict
            :insufficient
          end
        end
      end
    end
    results = Timeout.timeout(15) do
      2.times { ready.pop }
      2.times { start << true }
      threads.map(&:value)
    end
    assert_equal [ :insufficient, :posted ], results.sort
    assert_equal 3, balance.reload.quantity
    assert_equal 1, StockMovement.where(organization: company).count
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
    if company&.persisted?
      [ DocumentEvent, StockMovement, WarehouseLine, WarehouseDocument, StockBalance, Product, StockWarehouse, User ].each do |model|
        model.where(organization_id: company.id).delete_all
      end
      company.reload.destroy!
    end
  end
end
