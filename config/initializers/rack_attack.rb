class Rack::Attack
  throttle("orders/create/ip", limit: 5, period: 60) do |req|
    next if Rails.env.test?

    req.ip if req.path == "/orders" && req.post?
  end

  self.throttled_responder = lambda do |_env|
    [ 429, { "Content-Type" => "application/json" }, [ { error: "Rate limit exceeded" }.to_json ] ]
  end
end
