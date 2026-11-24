class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def organization_admin?
    user&.active? && user.admin? && !user.password_change_required? &&
      user.organization_id == record.organization_id
  end
end
