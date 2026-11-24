class DocumentEvent < ApplicationRecord
  belongs_to :user
  belongs_to :warehouse_document
end
