class PasswordRecoveryMailer < ApplicationMailer
  def changed(user)
    mail(to: user.email_address, subject: "Пароль изменён — СЕКЦИЯ",
      body: "Пароль вашей учётной записи изменён. Если это были не вы, свяжитесь с администратором своей фирмы. Старые сессии завершены.",
      content_type: "text/plain")
  end

  def reset_link(user, token)
    @reset_url = password_reset_url(token: token)
    mail(to: user.email_address, subject: "Восстановление доступа — СЕКЦИЯ")
  end
end
