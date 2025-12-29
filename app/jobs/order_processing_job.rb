class OrderProcessingJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return if order.nil?
    return if order.processed?

    sleep 2

    order.with_lock do
      return if order.processed?
      order.update!(status: :processed, processed_at: Time.current)
    end
  end
end
