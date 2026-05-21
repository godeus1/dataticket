module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      token = request.params[:token]
      reject_unauthorized_connection unless token

      payload = JWT.decode(
        token,
        ENV.fetch("DEVISE_JWT_SECRET_KEY", "fallback-insecure-key-for-dev-only"),
        true,
        algorithms: ["HS256"]
      ).first

      jti     = payload["jti"]
      user_id = payload["sub"]

      reject_unauthorized_connection if JwtDenylist.exists?(jti: jti)

      user = User.find_by(id: user_id)
      reject_unauthorized_connection unless user&.active?

      user
    rescue JWT::DecodeError
      reject_unauthorized_connection
    end
  end
end
