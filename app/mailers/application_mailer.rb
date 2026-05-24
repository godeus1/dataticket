class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SMTP_USER", "noreply@dataticket.app")
  layout "mailer"

  after_action :log_delivery

  private

  def safe_smtp_pass(org)
    org&.smtp_pass.presence || ENV.fetch("SMTP_PASS", "")
  rescue => e
    Rails.logger.error("[mailer] falha ao ler smtp_pass: #{e.message} — usando fallback env var")
    ENV.fetch("SMTP_PASS", "")
  end

  def log_delivery
    to = message.to&.join(", ") || "(sem destinatário)"
    Rails.logger.info("[mailer] #{mailer_name}##{action_name} → #{to}")
  end

  # Sobrescreve as configurações SMTP globais com os valores salvos na organização.
  # Permite que o admin configure tudo pela tela de Configurações sem acesso ao Railway.
  # Se smtp_pass não estiver na org, cai no fallback das variáveis de ambiente.
  def mail(headers = {}, &block)
    org = begin
      Organization.first
    rescue => e
      Rails.logger.error("[mailer] falha ao carregar organização: #{e.message}")
      nil
    end

    pass      = safe_smtp_pass(org)
    host      = org&.smtp_host.presence || ENV.fetch("SMTP_HOST", "smtp.office365.com")
    port      = (org&.smtp_port || ENV.fetch("SMTP_PORT", "587")).to_i
    from_addr = org&.smtp_user.presence || ENV.fetch("SMTP_USER", "noreply@dataticket.app")

    if pass.present?
      headers[:from] ||= from_addr
      headers[:delivery_method_options] = {
        address:              host,
        port:                 port,
        user_name:            from_addr,
        password:             pass,
        authentication:       :login,
        enable_starttls_auto: true,
        open_timeout:         10,
        read_timeout:         15
      }
    end
    super
  end
end
