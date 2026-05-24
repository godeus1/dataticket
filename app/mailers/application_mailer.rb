class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SMTP_USER", "noreply@dataticket.app")
  layout "mailer"

  private

  # Sobrescreve as configurações SMTP globais com os valores salvos na organização.
  # Permite que o admin configure tudo pela tela de Configurações sem acesso ao Railway.
  # Se smtp_pass não estiver na org, cai no fallback das variáveis de ambiente.
  def mail(headers = {}, &block)
    org       = Organization.first
    pass      = org&.smtp_pass.presence || ENV.fetch("SMTP_PASS", "")
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
        enable_starttls_auto: true
      }
    end
    super
  end
end
