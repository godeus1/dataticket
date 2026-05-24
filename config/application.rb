require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DataticketApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # ActiveRecord Encryption — smtp_pass e outros campos sensíveis
    config.active_record.encryption.primary_key        = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY", "dev-primary-key-32-chars-padding!")
    config.active_record.encryption.deterministic_key  = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY", "dev-deterministic-key-32-chars!!")
    config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT", "dev-key-derivation-salt-32-chars!")

    # Devise/Warden precisa de session + cookie middleware mesmo em API mode
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, key: "_dataticket_session"

    # Rate limiting
    config.middleware.use Rack::Attack

    # Action Mailbox — relay ingress (configure MX/SMTP forwarder to POST to
    # https://<host>/rails/action_mailbox/relay/inbound_emails)
    config.action_mailbox.ingress = :relay

    # PrometheusMiddleware is registered via config/initializers/prometheus.rb
    # after the app constants are loaded

    # Action Cable — origens permitidas para WebSocket
    allowed = ENV.fetch("ALLOWED_ORIGINS", "http://localhost:5173,http://localhost:4173")
                 .split(",")
                 .map { |o| o.strip }
    config.action_cable.allowed_request_origins = allowed
    config.action_cable.mount_path = "/cable"
  end
end
