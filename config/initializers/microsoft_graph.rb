require "microsoft_graph_delivery_method"

ActionMailer::Base.add_delivery_method(
  :microsoft_graph,
  MicrosoftGraphDeliveryMethod,
  tenant_id:     ENV.fetch("MS_TENANT_ID", ""),
  client_id:     ENV.fetch("MS_CLIENT_ID", ""),
  client_secret: ENV.fetch("MS_CLIENT_SECRET", ""),
  sender:        ENV.fetch("MAIL_FROM", "")
)
