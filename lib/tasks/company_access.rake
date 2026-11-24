namespace :warehouse do
  desc "Create a company, first warehouse and administrator without modifying existing accounts"
  task onboard: :environment do
    organization = OrganizationOnboarding.from_environment
    puts "Organization #{organization.id} is ready. Existing passwords were not changed."
  end
end
