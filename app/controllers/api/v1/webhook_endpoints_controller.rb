module Api
  module V1
    class WebhookEndpointsController < ApplicationController
      before_action :set_endpoint, only: %i[show update destroy test_delivery]

      def index
        authorize WebhookEndpoint
        endpoints = policy_scope(WebhookEndpoint).order(created_at: :desc)
        render json: WebhookEndpointBlueprint.render_as_hash(endpoints)
      end

      def show
        authorize @endpoint
        render json: WebhookEndpointBlueprint.render_as_hash(@endpoint)
      end

      def create
        authorize WebhookEndpoint
        endpoint = @organization.webhook_endpoints.create!(endpoint_params)
        render json: WebhookEndpointBlueprint.render_as_hash(endpoint), status: :created
      end

      def update
        authorize @endpoint
        @endpoint.update!(endpoint_params)
        render json: WebhookEndpointBlueprint.render_as_hash(@endpoint)
      end

      def destroy
        authorize @endpoint
        @endpoint.destroy!
        head :no_content
      end

      # POST /webhook_endpoints/:id/test — sends a ping payload to verify the URL
      def test_delivery
        authorize @endpoint, :update?
        WebhookDeliveryJob.perform_later(
          @organization.id,
          "webhook.ping",
          { message: "DataTicket webhook test", endpoint_id: @endpoint.id, sent_at: Time.current }
        )
        render json: { message: "Payload de teste enfileirado" }
      end

      private

      def set_endpoint
        @endpoint = policy_scope(WebhookEndpoint).find(params[:id])
      end

      def endpoint_params
        params.require(:webhook_endpoint).permit(:name, :url, :secret, :active, events: [])
      end
    end
  end
end
