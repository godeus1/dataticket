require "rails_helper"

RSpec.describe "Tickets API", type: :request do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin,   organization: organization, password: "Password123!") }
  let(:user)         { create(:user,            organization: organization, password: "Password123!") }

  def auth_headers(u)
    post "/api/v1/login", params: { user: { email: u.email, password: "Password123!" } }, as: :json
    token = JSON.parse(response.body)["token"]
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/tickets" do
    let!(:ticket) { create(:ticket, organization: organization, requester: user) }

    it "retorna lista paginada de tickets" do
      get "/api/v1/tickets", headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["tickets"]).to be_an(Array)
      expect(body["pagination"]).to be_present
    end

    it "usuario comum ve apenas seus proprios tickets" do
      get "/api/v1/tickets", headers: auth_headers(user)
      body = JSON.parse(response.body)
      ids = body["tickets"].map { |t| t["id"] }
      expect(ids).to include(ticket.id)
    end
  end

  describe "POST /api/v1/tickets" do
    it "cria um ticket e retorna 201" do
      post "/api/v1/tickets",
           params: { ticket: { title: "Novo ticket", ticket_type: "incidente" } },
           headers: auth_headers(user),
           as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["id"]).to match(/^[A-Z][A-Z0-9]*-\d+$/)
      expect(body["ticket_type"]).to eq("incidente")
    end

    it "retorna 422 sem titulo" do
      post "/api/v1/tickets",
           params: { ticket: { title: "" } },
           headers: auth_headers(user),
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v1/tickets/:id/change_status" do
    let(:ticket) { create(:ticket, :in_progress, organization: organization, requester: user, assignee: admin) }

    it "altera o status com transicao valida" do
      patch "/api/v1/tickets/#{ticket.id}/change_status",
            params: { status: "Resolvido" },
            headers: auth_headers(admin),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["status"]).to eq("Resolvido")
    end

    it "rejeita transicao invalida" do
      patch "/api/v1/tickets/#{ticket.id}/change_status",
            params: { status: "Triado, aguardando atendimento" },
            headers: auth_headers(admin),
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/tickets/bulk_triage" do
    let!(:t1) { create(:ticket, organization: organization, requester: user) }
    let!(:t2) { create(:ticket, organization: organization, requester: user) }
    let!(:priority) { create(:priority, organization: organization) }

    it "triagem em lote — admin pode triar multiplos tickets" do
      post "/api/v1/tickets/bulk_triage",
           params: { ticket_ids: [t1.id, t2.id], priority_id: priority.id },
           headers: auth_headers(admin),
           as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["triaged"]).to include(t1.id, t2.id)
    end

    it "usuario comum nao tem acesso" do
      post "/api/v1/tickets/bulk_triage",
           params: { ticket_ids: [t1.id] },
           headers: auth_headers(user),
           as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
