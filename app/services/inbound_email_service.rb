require "microsoft_graph_mail_reader"

# Transforma respostas de e-mail (capturadas na caixa via Microsoft Graph) em
# comentários nos tickets correspondentes.
#
# Casamento: o assunto dos e-mails enviados pelo DataTicket contém o ID do
# ticket (ex.: "[DataTicket] Novo comentário no ticket SAL-00001"); a resposta
# mantém "Re: ..." e o ID é extraído por regex.
#
# Autor: se o remetente bate com um usuário do DataTicket na empresa do ticket,
# o comentário sai vinculado a ele; caso contrário, é gravado como
# "Desconhecido" com o e-mail do remetente.
class InboundEmailService
  # Extrai o ID do ticket do assunto. Prioriza o trecho "no ticket <ID>" e cai
  # para um padrão genérico PREFIXO-NUMERO.
  TICKET_FROM_SUBJECT = /no ticket\s+([A-Z0-9]{2,10}-\d+)/i
  TICKET_GENERIC      = /\b([A-Z]{2,10}-\d{3,})\b/

  # Marcadores que indicam o início do texto citado (histórico) numa resposta.
  QUOTE_MARKERS = [
    /^\s*>/,                                   # linhas citadas
    /^\s*De:\s/i, /^\s*From:\s/i,              # cabeçalho encaminhado
    /^\s*Em .*escreveu:/i, /^\s*On .*wrote:/i, # "Em <data>, fulano escreveu:"
    /^\s*-{3,}\s*Mensagem original/i,
    /^_{5,}/,                                  # divisória do Outlook
    /\[DataTicket\]/i,                         # nosso próprio e-mail citado
  ].freeze

  def self.poll!(limit: 50)
    return 0 unless MicrosoftGraphMailReader.configured? && MicrosoftGraphMailReader.mailbox.present?

    new.poll!(limit: limit)
  end

  def poll!(limit: 50)
    mailbox = MicrosoftGraphMailReader.mailbox.downcase
    reader  = MicrosoftGraphMailReader.new

    reader.each_unread(limit: limit) do |msg|
      next false if msg[:from_email].blank? || msg[:from_email] == mailbox # ignora os próprios envios

      ticket = find_ticket(msg[:subject])
      next false unless ticket # não é resposta a um ticket conhecido → deixa intacta

      create_comment(ticket, msg)
      true # processado → marca como lida
    end
  rescue => e
    Rails.logger.error("[inbound_email] erro no poll: #{e.class}: #{e.message}")
    0
  end

  private

  def find_ticket(subject)
    id = subject[TICKET_FROM_SUBJECT, 1] || subject[TICKET_GENERIC, 1]
    id && Ticket.find_by(id: id)
  end

  def create_comment(ticket, msg)
    body = clean_reply(msg[:body_text])
    return if body.blank?

    author = ticket.organization.users.find_by("lower(email) = ?", msg[:from_email])

    comment = ticket.comments.create!(
      body:         body,
      kind:         "public",
      source:       "email",
      user:         author,
      author_name:  author ? nil : (msg[:from_name].presence || "Desconhecido"),
      author_email: author ? nil : msg[:from_email]
    )

    notify(ticket, comment, author)
    Rails.logger.info("[inbound_email] comentário criado no ticket #{ticket.id} (de #{msg[:from_email]}, autor=#{author&.id || 'desconhecido'})")
  rescue => e
    Rails.logger.error("[inbound_email] falha ao criar comentário no ticket #{ticket.id}: #{e.message}")
  end

  # Mantém apenas o texto novo da resposta, removendo o histórico citado.
  def clean_reply(text)
    lines = text.to_s.gsub("\r\n", "\n").split("\n")
    kept  = []
    lines.each do |line|
      break if QUOTE_MARKERS.any? { |re| line.match?(re) }

      kept << line
    end
    kept.join("\n").strip
  end

  def notify(ticket, comment, author)
    # Notifica em-app os envolvidos (exceto o próprio autor, quando conhecido).
    NotificationService.new(ticket).notify_new_comment(author)

    # Avisa o responsável por e-mail (sem reenviar para quem respondeu).
    return unless ticket.organization.email_type_enabled?("new_comment")

    assignee = ticket.assignee
    return if assignee.nil? || assignee == author

    TicketMailer.new_comment(ticket, comment, assignee).deliver_later
  rescue => e
    Rails.logger.error("[inbound_email] falha ao notificar ticket #{ticket.id}: #{e.message}")
  end
end
