require "test_helper"

class RegistrationOptionsTest < ActionDispatch::IntegrationTest
  test "returns registration options without authentication" do
      other_organization = Organization.create!(
      name: "Другая фирма",
      legal_form: "ooo"
    )

    other_warehouse = other_organization.warehouses.create!(
    name: "Чужой склад"
    )
    get "/registration_options"
     assert_response :ok
     body = response.parsed_body
     assert_instance_of Array, body
     organization_data = body.find do |item|
      item["id"] == organizations(:one).id
    end
    assert_not_nil organization_data
    expected_warehouse = warehouses(:one)

    assert_equal expected_warehouse.id,
             organization_data["warehouses"].first["id"]
     assert_instance_of Array, organization_data["warehouses"]
     expected_warehouse = warehouses(:one)
     assert_equal expected_warehouse.id, organization_data["warehouses"].first["id"]
     warehouse_ids = organization_data["warehouses"].map do |warehouse|
      warehouse["id"]
    end
      assert_not_includes warehouse_ids, other_warehouse.id
      other_data = body.find do |item|
        item["id"]== other_organization.id
      end
      assert_not_nil other_data
    assert_equal [ other_warehouse.id ],
             other_data["warehouses"].map { |warehouse| warehouse["id"] }
    # Возврат разрешенных полей
    assert_equal [ "id", "name", "warehouses" ].sort, organization_data.keys.sort
    warehouse_data = organization_data["warehouses"].first
    assert_equal [ "id", "name" ].sort,
             warehouse_data.keys.sort
  end
end
