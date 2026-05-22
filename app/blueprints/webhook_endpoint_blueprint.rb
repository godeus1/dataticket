class WebhookEndpointBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :url, :events, :active, :created_at, :updated_at

  # Never expose the signing secret in list/show responses
  field :has_secret do |endpoint|
    endpoint.secret.present?
  end
end
