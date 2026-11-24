class OrganizationOnboarding
  class Conflict < StandardError; end

  def self.from_environment
    call(code: ENV.fetch("WAREHOUSE_ORGANIZATION_CODE"), name: ENV.fetch("WAREHOUSE_ORGANIZATION_NAME"),
      legal_form: ENV.fetch("WAREHOUSE_ORGANIZATION_LEGAL_FORM"), warehouse_name: ENV.fetch("WAREHOUSE_NAME"),
      admin_name: ENV.fetch("WAREHOUSE_ADMIN_NAME"), admin_email: ENV.fetch("WAREHOUSE_ADMIN_EMAIL"),
      admin_password: ENV["WAREHOUSE_ADMIN_PASSWORD"])
  end

  def self.call(code:, name:, legal_form:, warehouse_name:, admin_name:, admin_email:, admin_password:)
    raise ArgumentError, "Код организации обязателен" if code.blank?
    organization = Organization.find_or_initialize_by(code: code.strip.downcase)
    Organization.transaction do
      if organization.persisted?
        organization.lock!
        admin = organization.users.find_by(email_address: admin_email)
        unless admin&.admin? && organization.name == name && organization.legal_form == legal_form &&
            organization.warehouses.exists?(name: warehouse_name)
          raise Conflict, "Код уже используется. Существующие данные не изменены."
        end
        return organization
      end
      raise Conflict, "Почта уже используется. Пользователь не будет перенесён из другой фирмы." if User.exists?(email_address: admin_email)
      raise ArgumentError, "Пароль первого администратора обязателен" if admin_password.blank?
      organization.assign_attributes(name: name, legal_form: legal_form)
      organization.save!
      organization.warehouses.create!(name: warehouse_name)
      admin = organization.users.create!(name: admin_name, email_address: admin_email,
        password: admin_password, password_confirmation: admin_password, role: "admin", status: "active", password_change_required: true)
      AccessEvent.create!(organization: organization, actor: admin, user: admin, action: "organization_onboarded")
    end
    organization
  rescue ActiveRecord::RecordNotUnique
    raise Conflict, "Организация или почта уже создана другим запросом. Повторите команду."
  end
end
