class IdempotencyKey < ApplicationRecord
  belongs_to :order

  validates :key, presence: true, uniqueness: true
  validates :request_hash, presence: true
end
