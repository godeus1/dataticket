require "prometheus/client/formats/text"

# Prometheus scraping endpoint.
#
# Proteção por Bearer token via variável de ambiente METRICS_AUTH_TOKEN.
# Configure no Railway / .env:
#   METRICS_AUTH_TOKEN=<token-secreto-forte>
#
# Prometheus scrape_config:
#   bearer_token: <mesmo-token>
#
# Se METRICS_AUTH_TOKEN não estiver definida, o endpoint fica aberto
# (aceitável apenas em desenvolvimento local).
class MetricsController < ActionController::API
  before_action :authenticate_metrics!

  def index
    registry = Prometheus::Client.registry
    render plain: Prometheus::Client::Formats::Text.marshal(registry),
           content_type: Prometheus::Client::Formats::Text::CONTENT_TYPE
  end

  private

  def authenticate_metrics!
    expected = ENV["METRICS_AUTH_TOKEN"].presence

    # Sem token configurado → aceita apenas em desenvolvimento
    unless expected
      return if Rails.env.development?

      render plain: "Unauthorized", status: :unauthorized and return
    end

    provided = request.headers["Authorization"].to_s
                      .delete_prefix("Bearer ")
                      .strip

    unless ActiveSupport::SecurityUtils.secure_compare(expected, provided)
      response.headers["WWW-Authenticate"] = 'Bearer realm="metrics"'
      render plain: "Unauthorized", status: :unauthorized
    end
  end
end
