class PasswordRecoveryRequest < ApplicationRecord
  belongs_to :organization
  belongs_to :user
  belongs_to :handled_by, class_name: "User", optional: true
  enum :status, { pending: "pending", completed: "completed", rejected: "rejected", superseded: "superseded" }, validate: true
  validates :expires_at, :credentials_version, presence: true
  validate :same_organization

  def actionable?
    pending? && expires_at.future? && credentials_version == user.credentials_version
  end

  private

  def same_organization
    errors.add(:user, "must belong to the same organization") if user && user.organization_id != organization_id
    errors.add(:handled_by, "must belong to the same organization") if handled_by && handled_by.organization_id != organization_id
  end
end
