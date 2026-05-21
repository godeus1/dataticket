require "rails_helper"

RSpec.describe "Health", type: :request do
  describe "GET /api/v1/health" do
    it "returns ok without authentication" do
      get "/api/v1/health"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("ok")
      expect(json["version"]).to be_present
      expect(json["timestamp"]).to be_present
    end
  end

  describe "GET /up" do
    it "returns the Rails health check" do
      get "/up"
      expect(response).to have_http_status(:ok)
    end
  end
end
