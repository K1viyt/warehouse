class User < ApplicationRecord
  has_secure_password
  belongs_to :organization
  has_many :warehouse_memberships, dependent: :restrict_with_error
  has_many :warehouses, through: :warehouse_memberships
  has_many :password_recovery_requests, dependent: :restrict_with_error
  before_update :rotate_credentials
  validates :password, length: { minimum: 8 }, allow_nil: true
  generates_token_for :account_recovery, expires_in: 15.minutes do
    [ credentials_version, email_address, email_verified? ]
  end

  def accessible_warehouses
    return organization.warehouses if admin?

    organization.warehouses.where(id: warehouse_memberships.active.select(:warehouse_id))
  end

  def email_verified?
    email_verified_at.present?
  end

    # enum ограничевает допустимые значения полей и открывает проверку user.admin?...
    enum :role, { operator: "operator", admin: "admin" }, validate: true
    enum :status, { pending: "pending", active: "active", blocked: "blocked" }, validate: true


    # normalizator к нижнему email
    normalizes :email_address, with: ->(email) { email.strip.downcase }
    validates :name, presence: true
    validates :email_address, presence: true, uniqueness: true
    generates_token_for :email_verification, expires_in: 30.minutes do
      [ email_address, email_verified? ]
    end
    validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  private

  def rotate_credentials
    if will_save_change_to_password_digest? || will_save_change_to_email_address? || (will_save_change_to_status? && blocked?)
      self.credentials_version += 1
    end
    self.email_verified_at = nil if will_save_change_to_email_address?
  end
end
