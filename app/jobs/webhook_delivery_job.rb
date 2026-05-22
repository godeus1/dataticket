class WebhookDeliveryJob < ApplicationJob
  queue_as :default

  # event   — e.g. "ticket.created"
  # payload — Hash that will be JSON-serialised and POSTed
  def perform(organization_id, event, payload)
    endpoints = WebhookEndpoint
                  .where(organization_id: organization_id)
                  .subscribed_to(event)

    endpoints.each do |endpoint|
      WebhookService.new(endpoint).deliver(event, payload)
    end
  end
end
