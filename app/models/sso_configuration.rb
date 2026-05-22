class SsoConfiguration < ApplicationRecord
  belongs_to :organization

  validates :idp_entity_id, :idp_sso_url, :idp_cert, :sp_entity_id, presence: true
  validates :organization_id, uniqueness: true  # one SSO per org

  # Builds a ruby-saml Settings object for this IdP configuration
  def saml_settings(request_host)
    require "onelogin/ruby-saml"

    settings                          = OneLogin::RubySaml::Settings.new
    settings.assertion_consumer_service_url = "#{request_host}/api/v1/sso/callback"
    settings.sp_entity_id             = sp_entity_id
    settings.idp_entity_id            = idp_entity_id
    settings.idp_sso_target_url       = idp_sso_url
    settings.idp_cert                 = idp_cert
    settings.name_identifier_format   = name_id_format
    settings.security[:authn_requests_signed]   = false
    settings.security[:want_assertions_signed]  = false
    settings
  end
end
