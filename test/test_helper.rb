ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Explicit fixture context keeps tests independent of migration-generated IDs.
    def create_user(**attributes)
      user = User.create!(organization: organizations(:one), **attributes)
      user.warehouse_memberships.create!(organization: user.organization,
        warehouse: warehouses(:one), status: user.status) unless user.admin?
      user
    end
  end
end
