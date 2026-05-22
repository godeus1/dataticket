class PasswordResetMailer < ApplicationMailer
  def reset_code(user, code)
    @user = user
    @code = code

    mail(
      to:      user.email,
      subject: "DataTicket — Código de redefinição de senha"
    )
  end
end
