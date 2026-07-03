require "net/http"
require "json"
require "uri"
require "base64"

# Delivery method que envia e-mail pela Microsoft Graph API (HTTP/443) — funciona
# no Railway, onde as portas de SMTP (25/465/587) são bloqueadas.
#
# Autenticação OAuth2 client_credentials (app-only): não exige interação do
# usuário nem refresh token. Requer um App Registration no Entra ID (Azure AD)
# com a permissão de APLICATIVO Mail.Send (com consentimento de admin).
#
# Variáveis necessárias (Railway):
#   MS_TENANT_ID      — id do tenant (ou domínio, ex: datatry.com.br)
#   MS_CLIENT_ID      — Application (client) ID do App Registration
#   MS_CLIENT_SECRET  — client secret do App Registration
#   MAIL_FROM         — caixa que envia (ex: e.oliveira@datatry.com.br)
#
# Envia o MIME bruto (mail.encoded) para /users/{remetente}/sendMail, preservando
# HTML/headers exatamente como os mailers geram.
class MicrosoftGraphDeliveryMethod
  GRAPH_HOST = "graph.microsoft.com".freeze

  # Erro TRANSITÓRIO (throttling 429 / 5xx) — o job de entrega faz retry com
  # backoff (ver initializer). Sem isso, e-mails que caem em rajadas (ex.:
  # vários envios simultâneos às 08:00) morrem com "ApplicationThrottled" e o
  # destinatário nunca recebe (caso real: código de reset de senha perdido).
  class TransientError < StandardError; end

  attr_accessor :settings

  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    token  = access_token
    sender = bare_email(settings[:sender].presence || Array(mail.from).first.to_s)
    raise ArgumentError, "MAIL_FROM (remetente) não configurado" if sender.empty?

    uri = URI("https://#{GRAPH_HOST}/v1.0/users/#{sender}/sendMail")
    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{token}"
    req["Content-Type"]  = "text/plain" # MIME bruto em base64
    req.body = Base64.strict_encode64(mail.encoded)

    response = https(uri).request(req)

    code = response.code.to_i
    unless code.between?(200, 299)
      if code == 429 || code >= 500
        raise TransientError, "Microsoft Graph #{code} (transitório): #{response.body[0, 300]}"
      end
      raise "Microsoft Graph error #{response.code}: #{response.body}"
    end

    Rails.logger.info("[ms_graph] enviado de #{sender} para #{Array(mail.to).join(', ')} — status #{response.code}")
    response
  rescue => e
    Rails.logger.error("[ms_graph] #{e.class}: #{e.message}")
    raise
  end

  private

  def access_token
    tenant = settings[:tenant_id].to_s
    raise ArgumentError, "MS_TENANT_ID não configurado" if tenant.empty?

    uri = URI("https://login.microsoftonline.com/#{tenant}/oauth2/v2.0/token")
    req = Net::HTTP::Post.new(uri)
    req.set_form_data(
      "client_id"     => settings[:client_id],
      "client_secret" => settings[:client_secret],
      "scope"         => "https://graph.microsoft.com/.default",
      "grant_type"    => "client_credentials"
    )

    response = https(uri).request(req)
    unless response.code.to_i == 200
      raise "Microsoft OAuth error #{response.code}: #{response.body}"
    end

    JSON.parse(response.body).fetch("access_token")
  end

  # Extrai o e-mail puro de "Nome <email>" ou retorna a própria string.
  def bare_email(value)
    value.to_s[/<([^>]+)>/, 1] || value.to_s.strip
  end

  def https(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.open_timeout = 10
    http.read_timeout = 20
    http
  end
end
