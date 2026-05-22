require "rails_helper"

RSpec.describe "Custom Fields API", type: :request do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin, organization: organization, password: "Password123!") }
  let(:analyst)      { create(:user, :analyst, organization: organization, password: "Password123!") }

  def auth_headers(u)
    post "/api/v1/login", params: { user: { email: u.email, password: "Password123!" } }, as: :json
    token = JSON.parse(response.body)["token"]
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/custom_fields" do
    let!(:cf) { create(:custom_field, organization: organization) }

    it "retorna lista de campos" do
      get "/api/v1/custom_fields", headers: auth_headers(analyst)
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.first["name"]).to eq(cf.name)
    end
  end

  describe "POST /api/v1/custom_fields" do
    it "admin cria campo de texto" do
      post "/api/v1/custom_fields",
           params: { custom_field: { name: "Versão do sistema", field_type: "text", required: false, position: 0 } },
           headers: auth_headers(admin),
           as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["field_type"]).to eq("text")
    end

    it "admin cria campo dropdown com opções" do
      post "/api/v1/custom_fields",
           params: { custom_field: { name: "Severidade", field_type: "dropdown", options: [ "Baixa", "Média", "Alta" ], required: true, position: 1 } },
           headers: auth_headers(admin),
           as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["options"]).to eq([ "Baixa", "Média", "Alta" ])
    end

    it "rejeita dropdown sem opções" do
      post "/api/v1/custom_fields",
           params: { custom_field: { name: "Campo vazio", field_type: "dropdown", options: [] } },
           headers: auth_headers(admin),
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "analista não pode criar campo" do
      post "/api/v1/custom_fields",
           params: { custom_field: { name: "Campo", field_type: "text" } },
           headers: auth_headers(analyst),
           as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "valores customizados no ticket" do
    let(:user)   { create(:user, organization: organization, password: "Password123!") }
    let!(:cf)    { create(:custom_field, organization: organization, name: "Versão", field_type: "text") }

    it "salva valores ao criar ticket" do
      post "/api/v1/tickets",
           params: {
             ticket: {
               title: "Ticket com campos",
               ticket_type: "incidente",
               custom_field_values: [ { custom_field_id: cf.id, value: "3.2.1" } ]
             }
           },
           headers: auth_headers(user),
           as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      fv = body["field_values"].find { |v| v["custom_field_id"] == cf.id }
      expect(fv).not_to be_nil
      expect(fv["value"]).to eq("3.2.1")
    end
  end
end
