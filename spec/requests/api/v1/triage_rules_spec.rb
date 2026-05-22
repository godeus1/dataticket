require "rails_helper"

RSpec.describe "Triage Rules API", type: :request do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin, organization: organization, password: "Password123!") }
  let(:analyst)      { create(:user, :analyst, organization: organization, password: "Password123!") }

  def auth_headers(u)
    post "/api/v1/login", params: { user: { email: u.email, password: "Password123!" } }, as: :json
    token = JSON.parse(response.body)["token"]
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/triage_rules" do
    let!(:rule) { create(:triage_rule, organization: organization) }

    it "returns list for admin" do
      get "/api/v1/triage_rules", headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to be_an(Array)
    end

    it "returns list for analyst" do
      get "/api/v1/triage_rules", headers: auth_headers(analyst)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/triage_rules" do
    it "allows admin to create a rule" do
      post "/api/v1/triage_rules",
           params: { triage_rule: { name: "Regra teste", keyword: "servidor", position: 0, active: true } },
           headers: auth_headers(admin),
           as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["keyword"]).to eq("servidor")
    end

    it "forbids analyst from creating a rule" do
      post "/api/v1/triage_rules",
           params: { triage_rule: { name: "Regra teste", keyword: "abc" } },
           headers: auth_headers(analyst),
           as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/triage_rules/:id" do
    let!(:rule) { create(:triage_rule, organization: organization) }

    it "allows admin to delete" do
      delete "/api/v1/triage_rules/#{rule.id}", headers: auth_headers(admin)
      expect(response).to have_http_status(:no_content)
    end
  end
end
