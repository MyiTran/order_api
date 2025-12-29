require "rails_helper"
RSpec.describe OrderItem, type: :model do
  it "requires sku" do
    item = OrderItem.new(sku: nil, quantity: 1, unit_price_cents: 100)
    expect(item).not_to be_valid
  end

  it "requires quantity > 0" do
    item = OrderItem.new(sku: "A", quantity: 0, unit_price_cents: 100)
    expect(item).not_to be_valid
  end
end
