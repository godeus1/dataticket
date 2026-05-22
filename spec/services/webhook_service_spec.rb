require "rails_helper"

RSpec.describe WebhookService do
  let(:organization) { create(:organization) }
  let(:endpoint) do
    WebhookEndpoint.new(
      organization: organization,
      name:   "Slack",
      url:    "https://hooks.example.com/webhook",
      secret: "mysecret",
      events: [ "ticket.created" ],
      active: true
    )
  end

  describe "#deliver" do
    let(:payload) { { id: "TK-0001", title: "Ticket de teste" } }

    it "sends a POST request to the endpoint URL" do
      stub = stub_request(:post, "https://hooks.example.com/webhook")
               .to_return(status: 200, body: "ok")

      described_class.new(endpoint).deliver("ticket.created", payload)
      expect(stub).to have_been_requested
    end

    it "includes the HMAC signature header" do
      stub = stub_request(:post, "https://hooks.example.com/webhook")
               .with(headers: { "X-DT-Event" => "ticket.created" })
               .to_return(status: 200, body: "ok")

      described_class.new(endpoint).deliver("ticket.created", payload)
      expect(stub).to have_been_requested
    end

    it "returns nil and logs on network error" do
      stub_request(:post, "https://hooks.example.com/webhook")
        .to_raise(Net::ReadTimeout)

      expect(Rails.logger).to receive(:error).with(/delivery failed/)
      result = described_class.new(endpoint).deliver("ticket.created", payload)
      expect(result).to be_nil
    end
  end
end
