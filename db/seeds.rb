# Explicit, repeatable onboarding; never reset an existing administrator password.
OrganizationOnboarding.from_environment if ENV["WAREHOUSE_ORGANIZATION_CODE"].present?
