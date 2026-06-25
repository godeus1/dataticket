require "net/http"
require "json"
require "uri"

# Lê mensagens da caixa de entrada via Microsoft Graph API (HTTP/443) — usado
# para capturar respostas de e-mail e transformá-las em comentários no ticket.
#
# Requer um App Registration no Entra ID com a permissão de APLICATIVO
# **Mail.Read** (com consentimento de admin) — além da Mail.Send já usada no
# envio. Reaproveita as mesmas credenciais (MS_TENANT_ID/MS_CLIENT_ID/
# MS_CLIENT_SECRET). A caixa lida é definida por MAIL_INBOX (default = MAIL_FROM).
#
# Fluxo: lista mensagens NÃO lidas da Inbox, entrega cada uma ao bloco e, se o
# processamento devolver truthy, marca a mensagem como lida (para não reprocessar).
class MicrosoftGraphMailReader
  GRAPH_HOST = "graph.microsoft.com".freeze

  def self.configured?
    ENV["MS_TENANT_ID"].present? && ENV["MS_CLIENT_ID"].present? && ENV["MS_CLIENT_SECRET"].present?
  end

  def self.mailbox
    (ENV["MAIL_INBOX"].presence || ENV["MAIL_FROM"].presence).to_s.strip
  end

  def initialize(tenant_id: ENV["MS_TENANT_ID"], client_id: ENV["MS_CLIENT_ID"],
                 client_secret: ENV["MS_CLIENT_SECRET"], mailbox: self.class.mailbox)
    @tenant_id     = tenant_id
    @client_id     = client_id
    @client_secret = client_secret
    @mailbox       = mailbox
  end

  # Itera sobre as mensagens não lidas. Para cada uma, chama o bloco com um hash
  # { id:, subject:, from_email:, from_name:, body_text:, received_at: }.
  # Se o bloco retornar truthy, a mensagem é marcada como lida.
  def each_unread(limit: 25)
    token = access_token
    msgs  = fetch_unread(token, limit)
    msgs.each do |m|
      parsed = {
        id:          m["id"],
        subject:     m.dig("subject").to_s,
        from_email:  m.dig("from", "emailAddress", "address").to_s.downcase,
        from_name:   m.dig("from", "emailAddress", "name").to_s,
        body_text:   extract_text(m["body"]),
        received_at: m["receivedDateTime"],
      }
      mark_read(token, m["id"]) if yield(parsed)
    end
    msgs.size
  end

  private

  def fetch_unread(token, limit)
    uri = URI("https://#{GRAPH_HOST}/v1.0/users/#{@mailbox}/mailFolders/inbox/messages")
    uri.query = URI.encode_www_form(
      "$filter"  => "isRead eq false",
      "$top"     => limit,
      "$select"  => "id,subject,from,body,receivedDateTime",
      "$orderby" => "receivedDateTime asc"
    )
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{token}"
    res = https(uri).request(req)
    raise "Graph mail read error #{res.code}: #{res.body}" unless res.code.to_i.between?(200, 299)

    JSON.parse(res.body).fetch("value", [])
  end

  def mark_read(token, message_id)
    uri = URI("https://#{GRAPH_HOST}/v1.0/users/#{@mailbox}/messages/#{message_id}")
    req = Net::HTTP::Patch.new(uri)
    req["Authorization"] = "Bearer #{token}"
    req["Content-Type"]  = "application/json"
    req.body = { isRead: true }.to_json
    https(uri).request(req)
  rescue => e
    Rails.logger.error("[ms_graph_read] falha ao marcar lida #{message_id}: #{e.message}")
  end

  # Extrai texto puro do corpo (Graph devolve { contentType:, content: }).
  def extract_text(body)
    content = body.is_a?(Hash) ? body["content"].to_s : body.to_s
    if body.is_a?(Hash) && body["contentType"].to_s.casecmp("html").zero?
      content = content.gsub(/<br\s*\/?>/i, "\n").gsub(/<\/(p|div)>/i, "\n").gsub(/<[^>]+>/, " ")
      content = CGI.unescapeHTML(content)
    end
    content
  end

  def access_token
    uri = URI("https://login.microsoftonline.com/#{@tenant_id}/oauth2/v2.0/token")
    req = Net::HTTP::Post.new(uri)
    req.set_form_data(
      "client_id"     => @client_id,
      "client_secret" => @client_secret,
      "scope"         => "https://graph.microsoft.com/.default",
      "grant_type"    => "client_credentials"
    )
    res = https(uri).request(req)
    raise "Microsoft OAuth error #{res.code}: #{res.body}" unless res.code.to_i == 200

    JSON.parse(res.body).fetch("access_token")
  end

  def https(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 20
    http
  end
end
