require "net/http"
require "json"
require "uri"
require "base64"

# Delivery method que envia e-mail pela Gmail API (HTTP/443) — funciona no Railway,
# onde as portas de SMTP (25/465/587) são bloqueadas.
#
# Autenticação via OAuth2 refresh token (sem senha de app, que só serve p/ SMTP):
#   1. Troca o refresh_token por um access_token no endpoint de token do Google.
#   2. Envia a mensagem RFC822 (base64url) via users.messages.send.
#
# Variáveis necessárias (Railway):
#   GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN
#   MAIL_FROM = e-mail da conta Google autenticada (ou um alias "send as" verificado).
#
# Obs: o Gmail envia como a conta autenticada; se o From não bater com a conta
# ou um alias verificado, o Google reescreve o remetente para a conta.
class GmailApiDeliveryMethod
  TOKEN_URI = URI("https://oauth2.googleapis.com/token").freeze
  SEND_URI  = URI("https://gmail.googleapis.com/gmail/v1/users/me/messages/send").freeze

  attr_accessor :settings

  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    token = access_token

    req = Net::HTTP::Post.new(SEND_URI)
    req["Authorization"] = "Bearer #{token}"
    req["Content-Type"]  = "application/json"
    req.body = { raw: Base64.urlsafe_encode64(mail.encoded) }.to_json

    response = https(SEND_URI).request(req)

    unless response.code.to_i.between?(200, 299)
      raise "Gmail API error #{response.code}: #{response.body}"
    end

    Rails.logger.info("[gmail_api] enviado para #{Array(mail.to).join(', ')} — status #{response.code}")
    response
  rescue => e
    Rails.logger.error("[gmail_api] #{e.class}: #{e.message}")
    raise
  end

  private

  # Troca o refresh_token por um access_token de curta duração.
  def access_token
    raise ArgumentError, "GOOGLE_REFRESH_TOKEN não configurado" if settings[:refresh_token].to_s.empty?

    req = Net::HTTP::Post.new(TOKEN_URI)
    req.set_form_data(
      "client_id"     => settings[:client_id],
      "client_secret" => settings[:client_secret],
      "refresh_token" => settings[:refresh_token],
      "grant_type"    => "refresh_token"
    )

    response = https(TOKEN_URI).request(req)
    unless response.code.to_i == 200
      raise "Gmail OAuth error #{response.code}: #{response.body}"
    end

    JSON.parse(response.body).fetch("access_token")
  end

  def https(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.open_timeout = 10
    http.read_timeout = 20
    http
  end
end
