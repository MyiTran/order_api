class OrdersController < ApplicationController
  # POST/orders
  def create
    idempotency_key_value = request.headers["Idempotency-Key"]
    if idempotency_key_value.nil? || idempotency_key_value.strip.empty?
      return render json: { error: "Idempotency-Key header is required" }, status: :bad_request
    end

    payload = order_params.to_h
    request_hash = RequestFingerprint.sha256_of(payload)

    existing_key = IdempotencyKey.find_by(key: idempotency_key_value)
    if existing_key
      if existing_key.request_hash == request_hash
        order = existing_key.order
        return render json: order_json(order).merge(replayed: true), status: :ok
      else
        return render json: { error: "Idempotency-Key reuse with different payload" }, status: :conflict
      end
    end

    created_order = nil

    Order.transaction do
      existing_key_again = IdempotencyKey.lock.find_by(key: idempotency_key_value)
      if existing_key_again
        if existing_key_again.request_hash == request_hash
          created_order = existing_key_again.order
          raise ActiveRecord::Rollback
        else
          render json: { error: "Idempotency-Key reuse with different payload" }, status: :conflict
          raise ActiveRecord::Rollback
        end
      end

      order = Order.new(status: :pending)
      items = payload.fetch("items")

      items.each do |item|
        order.order_items.build(
          sku: item["sku"],
          quantity: item["quantity"],
          unit_price_cents: item["unit_price_cents"]
        )
      end

      order.save!

      IdempotencyKey.create!(
        key: idempotency_key_value,
        request_hash: request_hash,
        order: order
      )

      created_order = order
    end

    return if performed?

    OrderProcessingJob.perform_later(created_order.id)

    render json: order_json(created_order), status: :created
  rescue KeyError
    render json: { error: "items is required" }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def show
    order = Order.includes(:order_items).find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found if order.nil?

    render json: order_json(order), status: :ok
  end

  def index
    scope = Order.includes(:order_items).order(created_at: :desc)

    if params[:status].present?
      if Order.statuses.key?(params[:status])
        scope = scope.where(status: Order.statuses[params[:status]])
      else
        return render json: { error: "Invalid status filter" }, status: :bad_request
      end
    end

    if params[:min_total_cents].present?
      scope = scope.where("total_cents >= ?", params[:min_total_cents].to_i)
    end

    if params[:max_total_cents].present?
      scope = scope.where("total_cents <= ?", params[:max_total_cents].to_i)
    end

    page = [ params[:page].to_i, 1 ].max
    per = params[:per].to_i
    per = 20 if per <= 0
    per = 100 if per > 100

    total_count = scope.count
    orders = scope.offset((page - 1) * per).limit(per)

    render json: {
      page: page,
      per: per,
      total: total_count,
      data: orders.map { |o| order_json(o) }
    }, status: :ok
  end

  private

  def order_params
    params.permit(items: [ :sku, :quantity, :unit_price_cents ])
  end

  def order_json(order)
    {
      id: order.id,
      status: order.status,
      total_cents: order.total_cents,
      processed_at: order.processed_at,
      created_at: order.created_at,
      items: order.order_items.map do |i|
        {
          sku: i.sku,
          quantity: i.quantity,
          unit_price_cents: i.unit_price_cents
        }
      end
    }
  end
end
