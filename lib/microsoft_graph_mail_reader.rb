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

  # Itera sobre as mensagens RECEBIDAS nos últimos `lookback_minutes`, da mais
  # nova para a mais antiga, INDEPENDENTE de estarem lidas ou não. Isso evita
  # depender do estado de leitura de caixas movimentadas (com backlog de não
  # lidos) e não modifica a caixa (não marca nada como lido). A deduplicação
  # entre ciclos fica a cargo do chamador (ProcessedInboundEmail).
  #
  # Para cada mensagem chama o bloco com:
  #   { id:, subject:, from_email:, from_name:, body_text:, received_at: }
  def each_recent(lookback_minutes: 30, limit: 50)
    token = access_token
    msgs  = fetch_recent(token, lookback_minutes, limit)
    msgs.each do |m|
      yield(
        id:          m["id"],
        subject:     m["subject"].to_s,
        from_email:  m.dig("from", "emailAddress", "address").to_s.downcase,
        from_name:   m.dig("from", "emailAddress", "name").to_s,
        body_text:   extract_text(m["body"]),
        received_at: m["receivedDateTime"]
      )
    end
    msgs.size
  end

  private

  def fetch_recent(token, lookback_minutes, limit)
    since = (Time.now.utc - (lookback_minutes * 60)).strftime("%Y-%m-%dT%H:%M:%SZ")
    uri = URI("https://#{GRAPH_HOST}/v1.0/users/#{@mailbox}/mailFolders/inbox/messages")
    uri.query = URI.encode_www_form(
      "$filter"  => "receivedDateTime ge #{since}",
      "$top"     => limit,
      "$select"  => "id,subject,from,body,receivedDateTime",
      "$orderby" => "receivedDateTime desc"
    )
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{token}"
    req["Prefer"]        = 'outlook.body-content-type="text"' # corpo já em texto puro
    res = https(uri).request(req)
    raise "Graph mail read error #{res.code}: #{res.body}" unless res.code.to_i.between?(200, 299)

    JSON.parse(res.body).fetch("value", [])
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
