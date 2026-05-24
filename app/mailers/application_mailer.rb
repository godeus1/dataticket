class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SMTP_USER", "noreply@dataticket.app")
  layout "mailer"

  private

  # Sobrescreve as configurações SMTP globais com os valores salvos na organização.
  # Permite que o admin configure tudo pela tela de Configurações sem acesso ao Railway.
  # Se smtp_pass não estiver na org, cai no fallback das variáveis de ambiente.
  def mail(headers = {}, &block)
    org = Organization.first
    if org&.smtp_pass.present?
      from_addr = org.smtp_user.presence || ENV.fetch("SMTP_USER", "noreply@dataticket.app")
      headers[:from] ||= from_addr
      headers[:delivery_method_options] = {
        address:              org.smtp_host.presence || ENV.fetch("SMTP_HOST", "smtp.office365.com"),
        port:                 (org.smtp_port || ENV.fetch("SMTP_PORT", "587")).to_i,
        user_name:            from_addr,
        password:             org.smtp_pass,
        authentication:       :login,
        enable_starttls_auto: true
      }
    end
    super
  end
end
