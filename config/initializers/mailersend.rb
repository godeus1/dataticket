require "mailersend_delivery_method"

ActionMailer::Base.add_delivery_method(
  :mailersend,
  MailersendDeliveryMethod,
  api_key: ENV.fetch("MAILERSEND_API_KEY", "")
)
