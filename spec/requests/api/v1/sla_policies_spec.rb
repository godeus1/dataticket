require "rails_helper"

RSpec.describe "SLA Policies API", type: :request do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin, organization: organization, password: "Password123!") }
  let(:priority)     { create(:priority, organization: organization) }

  def auth_headers(u)
    post "/api/v1/login", params: { user: { email: u.email, password: "Password123!" } }, as: :json
    token = JSON.parse(response.body)["token"]
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/sla_policies" do
    let!(:policy) { create(:sla_policy, organization: organization, priority: priority) }

    it "returns active policies" do
      get "/api/v1/sla_policies", headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to be_an(Array)
    end
  end

  describe "POST /api/v1/sla_policies" do
    it "creates a new SLA policy" do
      post "/api/v1/sla_policies",
           params: { sla_policy: { priority_id: priority.id, response_hours: 2, resolve_hours: 8, active: true } },
           headers: auth_headers(admin),
           as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["resolve_hours"]).to eq(8)
    end

    it "rejects a policy with no priority or category" do
      post "/api/v1/sla_policies",
           params: { sla_policy: { response_hours: 2, resolve_hours: 8 } },
           headers: auth_headers(admin),
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
