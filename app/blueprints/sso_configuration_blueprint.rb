class SsoConfigurationBlueprint < Blueprinter::Base
  identifier :id

  fields :idp_entity_id, :idp_sso_url, :sp_entity_id,
         :name_id_format, :active, :created_at, :updated_at

  # Never expose the IdP certificate in the response (sensitive)
  field :has_certificate do |sso|
    sso.idp_cert.present?
  end
end
