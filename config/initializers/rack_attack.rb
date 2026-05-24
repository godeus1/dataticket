# frozen_string_literal: true
# config/initializers/rack_attack.rb
#
# Rate-limits e proteção contra força bruta.
# Usa o Rails cache (Solid Cache em produção, memory_store em dev/test).

class Rack::Attack
  # ── Safelists ──────────────────────────────────────────────────────────────

  # Health checks nunca são bloqueados (evita falsos positivos em probes)
  safelist("health checks") do |req|
    req.path == "/api/v1/health" || req.path == "/up"
  end

  # ── Throttles ──────────────────────────────────────────────────────────────

  # 1. Requisições gerais por IP: 300 req / 5 min
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # 2. Tentativas de login por IP: 10 tentativas / 20 min (brute force por IP)
  throttle("logins/ip", limit: 10, period: 20.minutes) do |req|
    req.ip if req.path == "/api/v1/login" && req.post?
  end

  # 3. Tentativas de login por e-mail: 5 tentativas / 20 min (credential stuffing)
  throttle("logins/email", limit: 5, period: 20.minutes) do |req|
    if req.path == "/api/v1/login" && req.post?
      body = req.body.read
      req.body.rewind
      params = JSON.parse(body) rescue {}
      params.dig("user", "email")&.downcase&.strip
    end
  end

  # 4. Reset de senha por IP: 5 tentativas / 15 min (evita enumeração de e-mails)
  throttle("password_reset/ip", limit: 5, period: 15.minutes) do |req|
    req.ip if req.path == "/api/v1/password_reset_request" && req.post?
  end

  # 5. Reset de senha por e-mail: 3 tentativas / 15 min (força bruta em e-mails específicos)
  throttle("password_reset/email", limit: 3, period: 15.minutes) do |req|
    if req.path == "/api/v1/password_reset_request" && req.post?
      body = req.body.read
      req.body.rewind
      params = JSON.parse(body) rescue {}
      params["email"]&.downcase&.strip
    end
  end

  # 7. SSO callback por IP: 20 req / min (IdP relay abuse)
  throttle("sso/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/sso/callback" && req.post?
  end

  # 8. CSAT público por IP: 10 envios / hora (ballot stuffing)
  throttle("csat/ip", limit: 10, period: 1.hour) do |req|
    req.ip if req.path.match?(%r{\A/api/v1/csat/}) && req.post?
  end

  # 9. API autenticada por token: 600 req / 5 min por token
  throttle("api/token", limit: 600, period: 5.minutes) do |req|
    if req.path.start_with?("/api/v1/")
      # Armazena apenas prefixo do token (evita guardar credenciais no cache)
      req.env["HTTP_AUTHORIZATION"].to_s.split.last.to_s.first(32).presence
    end
  end

  # ── Respostas padronizadas ─────────────────────────────────────────────────

  self.throttled_responder = lambda do |_env|
    [
      429,
      { "Content-Type" => "application/json" },
      [{ error: "Muitas requisições. Tente novamente em alguns minutos.", code: "rate_limited" }.to_json]
    ]
  end

  self.blocklisted_responder = lambda do |_env|
    [
      403,
      { "Content-Type" => "application/json" },
      [{ error: "Acesso bloqueado.", code: "blocked" }.to_json]
    ]
  end
end
