class UserPolicy < ApplicationPolicy
  def reset_password?
    organization_admin? && !record.admin? && user.id != record.id
  end
end
