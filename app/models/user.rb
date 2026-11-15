class User < ApplicationRecord
  has_secure_password
  belongs_to :organization
  has_many :warehouse_memberships, dependent: :restrict_with_error
  has_many :warehouses, through: :warehouse_memberships

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
end
