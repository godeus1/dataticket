require "rails_helper"

RSpec.describe "Organizations API", type: :request do
  let(:account)  { create(:account) }
  let(:org_a)    { create(:organization, account: account) }
  let(:org_b)    { create(:organization, account: account) }
  let(:admin_a)  { create(:user, :admin,     organization: org_a, password: "Password123!") }
  let(:msp)      { create(:user, :msp_admin, organization: org_a, password: "Password123!") }

  def login(u)
    post "/api/v1/login", params: { user: { email: u.email, password: "Password123!" } }, as: :json
    auth = response.headers["Authorization"]
    auth ? auth.sub(/^Bearer\s+/i, "") : nil
  end

  def headers(u) = { "Authorization" => "Bearer #{login(u)}" }

  describe "GET /api/v1/organizations" do
    before { org_a; org_b }

    it "msp_admin vê todas as empresas da conta" do
      get "/api/v1/organizations", headers: headers(msp)
      slugs = JSON.parse(response.body).map { |o| o["slug"] }
      expect(slugs).to include(org_a.slug, org_b.slug)
    end

    it "admin comum vê apenas a própria empresa" do
      get "/api/v1/organizations", headers: headers(admin_a)
      slugs = JSON.parse(response.body).map { |o| o["slug"] }
      expect(slugs).to eq([org_a.slug])
    end
  end

  describe "POST /api/v1/organizations" do
    it "msp_admin cria empresa sob a conta, com seed mínimo" do
      h = headers(msp)  # força criação de msp/org_a/conta antes de medir a contagem
      expect {
        post "/api/v1/organizations",
             params: { organization: { name: "Nova Co", slug: "nova-co", ticket_prefix: "NOV" } },
             headers: h, as: :json
      }.to change(Organization, :count).by(1)

      expect(response).to have_http_status(:created)
      org = Organization.find_by(slug: "nova-co")
      expect(org.account_id).to eq(account.id)
      expect(org.ticket_prefix).to eq("NOV")
      expect(org.priorities.count).to eq(4)
      expect(org.categories.count).to eq(1)
    end

    it "admin comum não pode criar empresa (403)" do
      post "/api/v1/organizations",
           params: { organization: { name: "X", slug: "x-co", ticket_prefix: "XCO" } },
           headers: headers(admin_a), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/organizations/:id (editar/inativar)" do
    before { org_a; org_b }

    it "msp_admin edita o nome da empresa" do
      patch "/api/v1/organizations/#{org_b.id}",
            params: { organization: { name: "Novo Nome" } }, headers: headers(msp), as: :json
      expect(response).to have_http_status(:ok)
      expect(org_b.reload.name).to eq("Novo Nome")
    end

    it "msp_admin inativa a empresa" do
      patch "/api/v1/organizations/#{org_b.id}",
            params: { organization: { active: false } }, headers: headers(msp), as: :json
      expect(response).to have_http_status(:ok)
      expect(org_b.reload.active).to be false
    end

    it "admin comum não consegue inativar (active é ignorado)" do
      patch "/api/v1/organizations/#{org_a.id}",
            params: { organization: { active: false } }, headers: headers(admin_a), as: :json
      expect(org_a.reload.active).to be true
    end
  end

  describe "login bloqueado em empresa inativa" do
    it "usuário de empresa inativa não loga (Empresa inativa)" do
      org_a.update!(active: false)
      post "/api/v1/login", params: { user: { email: admin_a.email, password: "Password123!" } }, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to match(/Empresa inativa/i)
    end

    it "msp_admin loga mesmo com a empresa-casa inativa" do
      org_a.update!(active: false)
      post "/api/v1/login", params: { user: { email: msp.email, password: "Password123!" } }, as: :json
      expect(response).to have_http_status(:ok)
    end
  end
end
