require "rails_helper"

RSpec.describe "Events API", type: :request do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin, organization: organization, password: "Password123!") }
  let(:ticket)       { create(:ticket, organization: organization, requester: admin) }

  def auth_headers(u)
    post "/api/v1/login", params: { user: { email: u.email, password: "Password123!" } }, as: :json
    token = JSON.parse(response.body)["token"]
    { "Authorization" => "Bearer #{token}" }
  end

  before do
    EventStore.publish(event_type: "ticket.created",       aggregate: ticket, actor: admin, organization: organization)
    EventStore.publish(event_type: "ticket.status_changed", aggregate: ticket, actor: admin, organization: organization)
  end

  describe "GET /api/v1/events" do
    it "retorna lista paginada de eventos" do
      get "/api/v1/events", headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["events"]).to be_an(Array)
      expect(body["events"].length).to be >= 2
    end

    it "filtra por aggregate_type" do
      get "/api/v1/events", params: { aggregate_type: "Ticket" }, headers: auth_headers(admin)
      body = JSON.parse(response.body)
      expect(body["events"].map { |e| e["aggregate_type"] }.uniq).to eq([ "Ticket" ])
    end

    it "filtra por aggregate_id (ticket específico)" do
      get "/api/v1/events", params: { aggregate_id: ticket.id }, headers: auth_headers(admin)
      body = JSON.parse(response.body)
      expect(body["events"].map { |e| e["aggregate_id"] }.uniq).to eq([ ticket.id ])
    end

    it "filtra por event_type" do
      get "/api/v1/events", params: { event_type: "ticket.created" }, headers: auth_headers(admin)
      body = JSON.parse(response.body)
      expect(body["events"].all? { |e| e["event_type"] == "ticket.created" }).to be true
    end
  end
end
