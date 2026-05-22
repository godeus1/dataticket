require "prometheus/client/formats/text"

# Prometheus scraping endpoint — no authentication (IP whitelist via reverse proxy)
class MetricsController < ActionController::API
  def index
    registry = Prometheus::Client.registry
    render plain: Prometheus::Client::Formats::Text.marshal(registry),
           content_type: Prometheus::Client::Formats::Text::CONTENT_TYPE
  end
end
