require "prometheus/client"
require "prometheus/client/formats/text"

class PrometheusMiddleware
  HTTP_REQUESTS  = Prometheus::Client.registry.counter(
    :http_requests_total,
    docstring: "Total de requisições HTTP",
    labels:    %i[method path status]
  )
  HTTP_DURATION  = Prometheus::Client.registry.histogram(
    :http_request_duration_seconds,
    docstring: "Duração das requisições HTTP em segundos",
    labels:    %i[method path],
    buckets:   [ 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5 ]
  )

  def initialize(app)
    @app = app
  end

  def call(env)
    start  = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status, headers, body = @app.call(env)

    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    path     = normalized_path(env)
    method   = env["REQUEST_METHOD"]

    HTTP_REQUESTS.increment(labels: { method: method, path: path, status: status.to_s })
    HTTP_DURATION.observe(duration, labels: { method: method, path: path })

    [ status, headers, body ]
  rescue StandardError => e
    HTTP_REQUESTS.increment(labels: { method: env["REQUEST_METHOD"],
                                       path: normalized_path(env),
                                       status: "500" })
    raise e
  end

  private

  # Collapse dynamic segments so cardinality stays low
  def normalized_path(env)
    path = env["PATH_INFO"].to_s
    path = path.gsub(%r{/TK-\d+}, "/:ticket_id")     # ticket IDs
               .gsub(%r{/\d+}, "/:id")                # numeric IDs
               .gsub(%r{/[a-f0-9\-]{36}}, "/:uuid")  # UUIDs
    path.empty? ? "/" : path
  end
end
