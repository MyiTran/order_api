class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy

  enum :status, [ :pending, :processed ]

  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }

  before_validation :recalculate_total

  def recalculate_total
    self.total_cents = order_items.sum { |i| i.quantity.to_i * i.unit_price_cents.to_i }
  end
end
