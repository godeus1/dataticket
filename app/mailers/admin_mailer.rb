# app/mailers/admin_mailer.rb
#
# E-mails operacionais enviados ao administrador da organização.
class AdminMailer < ApplicationMailer
  # Alerta de falha/ausência de backup do banco de dados.
  # Chamado pelo DatabaseBackupJob quando o backup não pode ser realizado.
  #
  # @param admin   [User]   administrador que receberá o alerta
  # @param message [String] descrição do problema
  def backup_alert(admin, message)
    @admin   = admin
    @message = message
    @date    = Time.current.strftime("%d/%m/%Y às %H:%M UTC")

    mail(
      to:      admin.email,
      subject: "[DataTicket] ⚠️ Alerta de Backup — #{@date}"
    )
  end
end
