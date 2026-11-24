class AccessEvent < ApplicationRecord
  belongs_to :organization
  belongs_to :user
  belongs_to :actor, class_name: "User"
  validates :action, presence: true
end
