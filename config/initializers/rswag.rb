Rswag::Ui.configure do |c|
  c.openapi_endpoint "/api-docs/v1/swagger.yaml", "DataTicket API v1"
end

Rswag::Api.configure do |c|
  c.openapi_root = Rails.root.join("swagger").to_s
end
