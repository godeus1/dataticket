class ProcessedInboundEmail < ApplicationRecord
  validates :message_id, presence: true, uniqueness: true
end
