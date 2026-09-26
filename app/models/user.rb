class User < ApplicationRecord
  has_secure_password

    # enum ограничевает допустимые значения полей и открывает проверку user.admin?...
    enum :role, { operator: "operator", admin: "admin" }, validate: true
    enum :status, { pending: "pending", active: "active", blocked: "blocked" }, validate: true


    # normalizator к нижнему email
    normalizes :email_address, with: ->(email) { email.strip.downcase }
    validates :name, presence: true
    validates :email_address, presence: true, uniqueness: true
end
