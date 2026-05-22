class SupportMailbox < ActionMailbox::Base
  # Resolve the organization from the recipient address or fall back to the first org.
  # Convention: support@<slug>.example.com → find org by slug, or just use organization.first.
  before_processing :find_organization
  before_processing :find_or_build_requester

  def process
    return bounce_with_delivery_error unless @organization

    ticket = @organization.tickets.create!(
      requester:   @requester,
      title:       mail.subject.to_s.strip.truncate(255).presence || "(sem assunto)",
      description: extract_body,
      ticket_type: "requisição",
      status:      "Não iniciado"
    )

    Rails.logger.info("[SupportMailbox] Ticket #{ticket.id} criado a partir do e-mail #{mail.message_id}")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[SupportMailbox] Falha ao criar ticket: #{e.message}")
    bounce_with_delivery_error
  end

  private

  def find_organization
    slug = recipient_slug
    @organization = slug ? Organization.find_by(slug: slug) : Organization.first
  end

  def find_or_build_requester
    sender_email = mail.from.first.to_s.downcase
    @requester   = User.find_by(email: sender_email) ||
                   create_guest_user(sender_email)
  end

  # Extract slug from recipient, e.g. support+salvabras@tickets.example.com → "salvabras"
  def recipient_slug
    recipient = mail.recipients.first.to_s
    match = recipient.match(/support\+([a-z0-9\-]+)@/i)
    match ? match[1].downcase : nil
  end

  def extract_body
    # Prefer plain text; fall back to stripped HTML
    if mail.multipart?
      part = mail.parts.find { |p| p.content_type.include?("text/plain") }
      part ? part.decoded.strip : ActionView::Base.full_sanitizer.sanitize(mail.decoded).strip
    elsif mail.content_type&.include?("text/plain")
      mail.decoded.strip
    else
      ActionView::Base.full_sanitizer.sanitize(mail.decoded).strip
    end
  rescue StandardError
    mail.decoded.to_s.strip.truncate(10_000)
  end

  def create_guest_user(email)
    name_parts = email.split("@").first.split(/[.\-_]/).map(&:capitalize)
    User.create!(
      email:      email,
      first_name: name_parts.first || "Solicitante",
      last_name:  name_parts[1..].join(" ").presence || "Externo",
      role:       "requester",
      organization: @organization,
      password:   SecureRandom.hex(16)
    )
  end
end
