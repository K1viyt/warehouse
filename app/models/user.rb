class User < ApplicationRecord
  has_secure_password

    # enum ограничевает допустимые значения полей и открывает проверку user.admin?...
    enum :role, { operator: "operator", admin: "admin" }, validate: true
    enum :status, { pending: "pending", active: "active", blocked: "blocked" }, validate: true
end
