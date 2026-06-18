require "rails_helper"

RSpec.describe "Ticket Attachments — lixeira", type: :request do
  let(:org)     { create(:organization) }
  let(:manager) { create(:user, :manager, organization: org, password: "Password123!") }
  let(:analyst) { create(:user, :analyst, organization: org, password: "Password123!") }
  let(:ticket)  { create(:ticket, organization: org, requester: analyst, assignee: analyst) }
  let!(:att) do
    TicketAttachment.create!(ticket: ticket, user: analyst, filename: "f.pdf",
                             content_type: "application/pdf", byte_size: 10,
                             storage_key: "tickets/#{ticket.id}/f.pdf")
  end

  def headers(u)
    post "/api/v1/login", params: { user: { email: u.email, password: "Password123!" } }, as: :json
    token = response.headers["Authorization"]&.sub(/^Bearer\s+/i, "")
    { "Authorization" => "Bearer #{token}" }
  end

  it "gestor move anexo para a lixeira (soft delete, não some do banco)" do
    h = headers(manager)
    expect {
      delete "/api/v1/tickets/#{ticket.id}/attachments/#{att.id}", headers: h
    }.not_to change(TicketAttachment, :count)
    expect(response).to have_http_status(:no_content)
    expect(att.reload.deleted?).to be true
    expect(att.deleted_by_id).to eq(manager.id)
  end

  it "analista NÃO pode deletar anexo (403)" do
    delete "/api/v1/tickets/#{ticket.id}/attachments/#{att.id}", headers: headers(analyst)
    expect(response).to have_http_status(:forbidden)
    expect(att.reload.deleted?).to be false
  end

  it "index lista só ativos; lixeira lista os deletados" do
    att.soft_delete!(manager)
    h = headers(manager)  # um único usuário por exemplo (evita conflito de sessão warden em specs)

    get "/api/v1/tickets/#{ticket.id}/attachments", headers: h
    expect(JSON.parse(response.body).map { |a| a["id"] }).not_to include(att.id)

    get "/api/v1/tickets/#{ticket.id}/attachments/trash", headers: h
    body = JSON.parse(response.body)
    expect(body.map { |a| a["id"] }).to include(att.id)
    expect(body.first["restorable_until"]).to be_present
  end

  it "gestor restaura anexo da lixeira" do
    att.soft_delete!(manager)
    patch "/api/v1/tickets/#{ticket.id}/attachments/#{att.id}/restore", headers: headers(manager)
    expect(response).to have_http_status(:ok)
    expect(att.reload.deleted?).to be false
  end

  it "analista não acessa a lixeira de anexos (403)" do
    get "/api/v1/tickets/#{ticket.id}/attachments/trash", headers: headers(analyst)
    expect(response).to have_http_status(:forbidden)
  end

  it "download de anexo na lixeira retorna 404" do
    att.soft_delete!(manager)
    get "/api/v1/tickets/#{ticket.id}/attachments/#{att.id}/download", headers: headers(manager)
    expect(response).to have_http_status(:not_found)
  end
end
