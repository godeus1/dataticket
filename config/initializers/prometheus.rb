require_relative "../../app/middleware/prometheus_middleware"

Rails.application.config.middleware.use PrometheusMiddleware
