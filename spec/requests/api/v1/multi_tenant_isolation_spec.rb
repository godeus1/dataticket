require "rails_helper"

# Garante o isolamento entre empresas (multi-tenant). Estes testes são a rede
# de segurança do Sprint 0: provam que dados de uma empresa NUNCA vazam para
# outra, que o msp_admin troca de empresa corretamente, e que papéis não-msp
# não conseguem forjar a troca via header.
RSpec.describe "Isolamento multi-tenant", type: :request do
  # Duas empresas sob a MESMA conta + uma empresa de OUTRA conta.
  let(:account1)  { create(:account) }
  let(:account2)  { create(:account) }
  let(:org_a)     { create(:organization, account: account1) }
  let(:org_b)     { create(:organization, account: account1) }
  let(:org_other) { create(:organization, account: account2) }

  let(:admin_a) { create(:user, :admin,     organization: org_a, password: "Password123!") }
  let(:admin_b) { create(:user, :admin,     organization: org_b, password: "Password123!") }
  let(:msp)     { create(:user, :msp_admin, organization: org_a, password: "Password123!") }

  # Dados isolados por empresa.
  let!(:ticket_a)   { create(:ticket,   organization: org_a, requester: admin_a) }
  let!(:ticket_b)   { create(:ticket,   organization: org_b, requester: admin_b) }
  let!(:category_a) { create(:category, organization: org_a) }
  let!(:category_b) { create(:category, organization: org_b) }

  def login(user)
    post "/api/v1/login",
         params: { user: { email: user.email, password: "Password123!" } },
         as: :json
    auth = response.headers["Authorization"]
    auth ? auth.sub(/^Bearer\s+/i, "") : JSON.parse(response.body)["token"]
  end

  def headers_for(user, org_id: nil)
    h = { "Authorization" => "Bearer #{login(user)}" }
    h["X-Organization-Id"] = org_id.to_s if org_id
    h
  end

  def ticket_ids(response)    = JSON.parse(response.body).fetch("tickets").map { |t| t["id"] }
  def category_ids(response)  = JSON.parse(response.body).map { |c| c["id"] }

  describe "admin comum: vê apenas a própria empresa" do
    it "admin de A vê o ticket de A e nunca o de B" do
      get "/api/v1/tickets", headers: headers_for(admin_a)
      ids = ticket_ids(response)
      expect(ids).to include(ticket_a.id)
      expect(ids).not_to include(ticket_b.id)
    end

    it "admin de B vê o ticket de B e nunca o de A" do
      get "/api/v1/tickets", headers: headers_for(admin_b)
      ids = ticket_ids(response)
      expect(ids).to include(ticket_b.id)
      expect(ids).not_to include(ticket_a.id)
    end
  end

  describe "msp_admin: troca de empresa com isolamento" do
    it "sem header → vê a empresa-casa (A)" do
      get "/api/v1/tickets", headers: headers_for(msp)
      ids = ticket_ids(response)
      expect(ids).to include(ticket_a.id)
      expect(ids).not_to include(ticket_b.id)
    end

    it "com header da empresa B → vê SOMENTE B (tickets via policy_scope)" do
      get "/api/v1/tickets", headers: headers_for(msp, org_id: org_b.id)
      ids = ticket_ids(response)
      expect(ids).to include(ticket_b.id)
      expect(ids).not_to include(ticket_a.id)
    end

    it "a troca também isola categorias (via @organization direto)" do
      get "/api/v1/categories", headers: headers_for(msp, org_id: org_b.id)
      ids = category_ids(response)
      expect(ids).to include(category_b.id)
      expect(ids).not_to include(category_a.id)
    end
  end

  describe "anti-spoofing: papel não-msp não troca de empresa" do
    it "admin comum enviando X-Organization-Id é IGNORADO" do
      get "/api/v1/tickets", headers: headers_for(admin_a, org_id: org_b.id)
      ids = ticket_ids(response)
      expect(ids).to include(ticket_a.id)      # permanece na própria empresa
      expect(ids).not_to include(ticket_b.id)  # nunca alcança a outra
    end
  end

  describe "msp_admin: não atravessa contas" do
    it "header apontando para empresa de OUTRA conta → 404" do
      get "/api/v1/tickets", headers: headers_for(msp, org_id: org_other.id)
      expect(response).to have_http_status(:not_found)
    end
  end
end
