# frozen_string_literal: true
# config/initializers/rack_attack.rb
#
# Rate-limits the API to prevent brute-force and abuse.
# Uses the Rails cache (Solid Cache in production, memory_store in dev/test).

class Rack::Attack
  # ── Throttles ──────────────────────────────────────────────────────────────

  # Limita todas as requisicoes por IP: 300 req / 5 min
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Limita tentativas de login: 10 tentativas / 20 min por IP
  throttle("logins/ip", limit: 10, period: 20.minutes) do |req|
    req.ip if req.path == "/api/v1/login" && req.post?
  end

  # Limita tentativas de login por e-mail: 5 tentativas / 20 min por e-mail
  throttle("logins/email", limit: 5, period: 20.minutes) do |req|
    if req.path == "/api/v1/login" && req.post?
      body = req.body.read
      req.body.rewind
      params = JSON.parse(body) rescue {}
      params.dig("user", "email")&.downcase&.strip
    end
  end

  # ── Resposta padrao ao bloquear ────────────────────────────────────────────
  self.throttled_responder = lambda do |_env|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "Muitas requisicoes. Tente novamente em alguns minutos." }.to_json ]
    ]
  end
end
