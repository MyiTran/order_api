require "rails_helper"

RSpec.describe "Orders API", type: :request do
  include ActiveJob::TestHelper

  let(:json_headers) { { "CONTENT_TYPE" => "application/json" } }

  let(:payload) do
    {
      items: [
        { sku: "A1", quantity: 2, unit_price_cents: 1500 },
        { sku: "B2", quantity: 1, unit_price_cents: 3000 }
      ]
    }
  end

  it "creates an order and enqueues processing job" do
    headers = json_headers.merge("Idempotency-Key" => "create-001")

    expect {
      post "/orders", params: payload.to_json, headers: headers
    }.to have_enqueued_job(OrderProcessingJob)

    expect(response).to have_http_status(:created)

    body = JSON.parse(response.body)
    expect(body["total_cents"]).to eq(6000)
    expect(body["status"]).to eq("pending")
  end

  it "replays when same Idempotency-Key and same payload" do
    headers = json_headers.merge("Idempotency-Key" => "replay-001")

    post "/orders", params: payload.to_json, headers: headers
    expect(response).to have_http_status(:created)
    first = JSON.parse(response.body)

    post "/orders", params: payload.to_json, headers: headers
    expect(response).to have_http_status(:ok)
    second = JSON.parse(response.body)

    expect(second["id"]).to eq(first["id"])
    expect(second["replayed"]).to eq(true)
  end

  it "returns 409 when same Idempotency-Key with different payload" do
    headers = json_headers.merge("Idempotency-Key" => "conflict-001")

    post "/orders", params: payload.to_json, headers: headers
    expect(response).to have_http_status(:created)

    changed_payload = {
      items: [ { sku: "A1", quantity: 3, unit_price_cents: 1500 } ]
    }

    post "/orders", params: changed_payload.to_json, headers: headers
    expect(response).to have_http_status(:conflict)
  end

  it "shows an order" do
    headers = json_headers.merge("Idempotency-Key" => "show-001")

    post "/orders", params: payload.to_json, headers: headers
    expect(response).to have_http_status(:created)

    order_id = JSON.parse(response.body)["id"]

    get "/orders/#{order_id}"
    expect(response).to have_http_status(:ok)
  end

  it "lists orders with pagination" do
    3.times do |i|
      headers = json_headers.merge("Idempotency-Key" => "list-#{i}")

      post "/orders",
           params: { items: [ { sku: "S#{i}", quantity: 1, unit_price_cents: 100 } ] }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
    end

    get "/orders?page=1&per=2"
    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body)
    expect(body["data"].length).to eq(2)
    expect(body["total"]).to be >= 3
  end
end
