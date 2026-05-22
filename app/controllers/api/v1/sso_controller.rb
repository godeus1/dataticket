require "onelogin/ruby-saml"

module Api
  module V1
    # SSO / SAML 2.0 controller — no authentication required (public endpoints)
    class SsoController < ActionController::API
      include ActionController::Cookies
      include ActionController::RequestForgeryProtection

      protect_from_forgery with: :null_session

      # GET /api/v1/sso/init?org=<slug>
      # Generates SAML AuthnRequest and redirects the browser to the IdP login page.
      def init
        org = Organization.find_by!(slug: params[:org])
        sso = org.sso_configuration

        return render json: { error: "SSO não configurado para esta organização" },
                      status: :not_found unless sso&.active?

        settings = sso.saml_settings(root_url)
        auth_request = OneLogin::RubySaml::Authrequest.new
        redirect_to auth_request.create(settings), allow_other_host: true
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Organização não encontrada" }, status: :not_found
      end

      # POST /api/v1/sso/callback
      # Processes IdP SAML Response, finds/creates user, and returns a JWT.
      def callback
        # Detect org from RelayState (we store org slug there) or session
        org_slug = params[:RelayState]
        org      = Organization.find_by(slug: org_slug)

        return render json: { error: "Organização inválida" }, status: :unprocessable_entity unless org

        sso = org.sso_configuration
        return render json: { error: "SSO não configurado" }, status: :unprocessable_entity unless sso&.active?

        settings = sso.saml_settings(root_url)
        response = OneLogin::RubySaml::Response.new(
          params[:SAMLResponse],
          settings: settings,
          allowed_clock_drift: 5.seconds
        )

        unless response.is_valid?
          Rails.logger.warn("[SsoController] SAML inválido: #{response.errors.join(', ')}")
          return render json: { error: "Resposta SAML inválida", details: response.errors },
                        status: :unauthorized
        end

        user = find_or_provision_user(org, response)
        token = generate_jwt(user)

        EventStore.publish(
          event_type:   "user.sso_login",
          aggregate:    user,
          payload:      { provider: "saml", org: org.slug },
          organization: org
        )

        response.headers["Authorization"] = "Bearer #{token}"
        render json: { token: token, user: { id: user.id, email: user.email, role: user.role } }
      rescue StandardError => e
        Rails.logger.error("[SsoController] callback error: #{e.message}")
        render json: { error: "Erro no processamento SAML" }, status: :internal_server_error
      end

      private

      def find_or_provision_user(org, saml_response)
        email      = saml_response.name_id.to_s.downcase.strip
        first_name = saml_response.attributes["firstName"] ||
                     saml_response.attributes["givenName"]  || email.split("@").first
        last_name  = saml_response.attributes["lastName"]  ||
                     saml_response.attributes["sn"]         || "SSO"

        org.users.find_by(email: email) ||
          org.users.create!(
            email:      email,
            first_name: first_name.to_s,
            last_name:  last_name.to_s,
            role:       "user",
            password:   SecureRandom.hex(24)
          )
      end

      def generate_jwt(user)
        # Reuse Devise-JWT token generation
        Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
      end

      def root_url
        "#{request.protocol}#{request.host_with_port}"
      end
    end
  end
end
