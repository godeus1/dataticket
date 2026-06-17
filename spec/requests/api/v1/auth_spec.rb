require "rails_helper"

RSpec.describe "Auth", type: :request do
  let(:organization) { create(:organization) }
  let!(:user)        { create(:user, organization: organization, password: "Password123!") }

  describe "POST /api/v1/login" do
    context "com credenciais validas" do
      it "retorna token JWT e dados do usuario" do
        post "/api/v1/login", params: {
          user: { email: user.email, password: "Password123!" }
        }, as: :json

        expect(response).to have_http_status(:ok)
        # devise-jwt despacha o token no header Authorization (não no corpo).
        expect(response.headers["Authorization"]).to match(/\ABearer .+/)
        body = JSON.parse(response.body)
        expect(body["user"]["email"]).to eq(user.email)
      end
    end

    context "com credenciais invalidas" do
      it "retorna 401" do
        post "/api/v1/login", params: {
          user: { email: user.email, password: "errada" }
        }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/logout" do
    it "invalida o token" do
      post "/api/v1/login", params: {
        user: { email: user.email, password: "Password123!" }
      }, as: :json

      token = JSON.parse(response.body)["token"]

      delete "/api/v1/logout",
             headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:no_content)
    end
  end
end
