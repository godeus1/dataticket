require "net/http"
require "openssl"

class WebhookService
  TIMEOUT = 10 # seconds

  def initialize(endpoint)
    @endpoint = endpoint
  end

  def deliver(event, payload)
    body    = payload.is_a?(String) ? payload : payload.to_json
    uri     = URI.parse(@endpoint.url)
    headers = build_headers(event, body)

    response = post(uri, body, headers)
    log_delivery(event, response.code)
    response
  rescue StandardError => e
    Rails.logger.error("[WebhookService] delivery failed to #{@endpoint.url}: #{e.message}")
    nil
  end

  private

  def post(uri, body, headers)
    http             = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl     = uri.scheme == "https"
    http.read_timeout = TIMEOUT
    http.open_timeout = TIMEOUT

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = body
    http.request(request)
  end

  def build_headers(event, body)
    headers = {
      "Content-Type" => "application/json",
      "User-Agent"   => "DataTicket-Webhook/1.0",
      "X-DT-Event"   => event,
      "X-DT-Timestamp" => Time.current.to_i.to_s
    }

    if @endpoint.secret.present?
      headers["X-DT-Signature"] = sign(body)
    end

    headers
  end

  def sign(body)
    digest = OpenSSL::HMAC.hexdigest("SHA256", @endpoint.secret, body)
    "sha256=#{digest}"
  end

  def log_delivery(event, status_code)
    Rails.logger.info("[WebhookService] #{event} → #{@endpoint.url} [#{status_code}]")
  end
end
