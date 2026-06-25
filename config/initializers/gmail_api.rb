require "gmail_api_delivery_method"

ActionMailer::Base.add_delivery_method(
  :gmail_api,
  GmailApiDeliveryMethod,
  client_id:     ENV.fetch("GOOGLE_CLIENT_ID", ""),
  client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET", ""),
  refresh_token: ENV.fetch("GOOGLE_REFRESH_TOKEN", "")
)
