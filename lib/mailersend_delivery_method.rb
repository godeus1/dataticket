require "net/http"
require "json"
require "uri"

# Delivery method customizado para o MailerSend HTTP API.
# Evita dependência de gem e funciona sem SMTP (porta 443 nunca bloqueada).
#
# Uso em production.rb:
#   config.action_mailer.delivery_method = :mailersend
#   config.action_mailer.mailersend_settings = { api_key: ENV["MAILERSEND_API_KEY"] }
#
class MailersendDeliveryMethod
  ENDPOINT = URI("https://api.mailersend.com/v1/email").freeze

  attr_accessor :settings

  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    api_key = settings[:api_key].to_s

    raise ArgumentError, "MAILERSEND_API_KEY não configurada" if api_key.empty?

    from_email = Array(mail.from).first.to_s
    from_name  = mail[:from]&.display_names&.first.presence || "DataTicket"

    payload = {
      from:    { email: from_email, name: from_name },
      to:      recipients(mail.to),
      subject: mail.subject.to_s,
      text:    plain_part(mail),
      html:    html_part(mail)
    }.compact

    http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
    http.use_ssl     = true
    http.open_timeout = 10
    http.read_timeout = 20

    req = Net::HTTP::Post.new(ENDPOINT.path)
    req["Authorization"]  = "Bearer #{api_key}"
    req["Content-Type"]   = "application/json"
    req.body = payload.to_json

    response = http.request(req)

    unless response.code.to_i.between?(200, 299)
      raise "MailerSend API error #{response.code}: #{response.body}"
    end

    Rails.logger.info("[mailersend] enviado para #{mail.to&.join(', ')} — status #{response.code}")
    response
  rescue => e
    Rails.logger.error("[mailersend] #{e.class}: #{e.message}")
    raise
  end

  private

  def recipients(addresses)
    Array(addresses).map { |addr| { email: addr } }
  end

  def plain_part(mail)
    if mail.multipart?
      mail.text_part&.decoded
    elsif mail.mime_type == "text/plain"
      mail.decoded
    end
  end

  def html_part(mail)
    if mail.multipart?
      mail.html_part&.decoded
    elsif mail.mime_type == "text/html"
      mail.decoded
    end
  end
end
