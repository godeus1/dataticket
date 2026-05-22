require "rails_helper"

RSpec.describe "Tags API", type: :request do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin,   organization: organization, password: "Password123!") }
  let(:analyst)      { create(:user, :analyst, organization: organization, password: "Password123!") }

  def auth_headers(u)
    post "/api/v1/login", params: { user: { email: u.email, password: "Password123!" } }, as: :json
    token = JSON.parse(response.body)["token"]
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/tags" do
    let!(:tag) { create(:tag, organization: organization) }

    it "retorna lista de tags" do
      get "/api/v1/tags", headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to be_an(Array)
    end
  end

  describe "POST /api/v1/tags" do
    it "analista pode criar tag" do
      post "/api/v1/tags",
           params: { tag: { name: "urgente", color: "#ff0000" } },
           headers: auth_headers(analyst),
           as: :json
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["name"]).to eq("urgente")
    end
  end

  describe "atribuição de tags ao ticket" do
    let(:user)   { create(:user, organization: organization, password: "Password123!") }
    let!(:tag1)  { create(:tag, organization: organization, name: "bug") }
    let!(:tag2)  { create(:tag, organization: organization, name: "urgente") }

    it "atribui tags ao criar ticket" do
      post "/api/v1/tickets",
           params: { ticket: { title: "Ticket com tags", ticket_type: "incidente", tag_ids: [ tag1.id, tag2.id ] } },
           headers: auth_headers(user),
           as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      tag_names = body["tags"].map { |t| t["name"] }
      expect(tag_names).to include("bug", "urgente")
    end

    it "filtra tickets por tag" do
      ticket = create(:ticket, organization: organization, requester: user)
      ticket.tags << tag1

      get "/api/v1/tickets", params: { tag_ids: [ tag1.id ] }, headers: auth_headers(admin)
      body = JSON.parse(response.body)
      expect(body["tickets"].map { |t| t["id"] }).to include(ticket.id)
    end
  end
end
