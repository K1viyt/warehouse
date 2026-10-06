admin_email = ENV.fetch("WAREHOUSE_ADMIN_EMAIL").strip.downcase
admin_password = ENV.fetch("WAREHOUSE_ADMIN_PASSWORD")

admin = User.find_or_initialize_by(email_address: admin_email)

admin.assign_attributes(
  name: ENV.fetch("WAREHOUSE_ADMIN_NAME", "Warehouse Administrator"),
  password: admin_password,
  password_confirmation: admin_password,
  role: "admin",
  status: "active"
)

admin.save!

puts "Administrator #{admin.email_address} is ready"
