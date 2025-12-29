require "rails_helper"
RSpec.describe Order, type: :model do
  it "calculates total_cents from items" do
    order = Order.new
    order.order_items.build(sku: "A", quantity: 2, unit_price_cents: 1000)
    order.order_items.build(sku: "B", quantity: 1, unit_price_cents: 500)

    order.valid?
    expect(order.total_cents).to eq(2500)
  end
end
