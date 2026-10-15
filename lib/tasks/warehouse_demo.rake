namespace :warehouse do
  desc "Add three illustrative catalog products without overwriting existing records"
  task demo_catalog: :environment do
    products = [
      { sku: "BOLT-M8", name: "Болт М8", unit: "шт" },
      { sku: "DOWEL-8", name: "Дюбель", unit: "шт" },
      { sku: "SCR-4.5", name: "Саморез", unit: "шт" }
    ]

    Product.transaction do
      products.each do |attributes|
        Product.find_or_create_by!(sku: attributes.fetch(:sku)) do |product|
          product.assign_attributes(attributes)
        end
      end
    end
    puts "Illustrative catalog is ready; existing products were preserved."
  end
end
