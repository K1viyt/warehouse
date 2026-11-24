class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("WAREHOUSE_MAIL_FROM", "from@example.com")
  layout "mailer"
end
