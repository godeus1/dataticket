source "https://rubygems.org"
ruby "3.3.11"

gem "rails", "~> 8.1.3"
gem "pg",    "~> 1.5"
gem "puma",  ">= 5.0"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]

# Rails 8 built-in adapters (sem Redis em dev)
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Deploy
gem "kamal",    require: false
gem "thruster", require: false
gem "image_processing", "~> 1.2"
gem "mini_magick", "~> 5.3"   # required by image_processing 1.x

# ── Autenticação ──────────────────────────────────────────────────────────────
gem "devise",     "~> 5.0"
gem "devise-jwt"   # sem constraint — usa versão mais recente

# ── Autorização ───────────────────────────────────────────────────────────────
gem "pundit", "~> 2.3"

# ── CORS ──────────────────────────────────────────────────────────────────────
gem "rack-cors", "~> 2.0"

# ── Rate limiting ─────────────────────────────────────────────────────────────
gem "rack-attack"

# ── Serialização ──────────────────────────────────────────────────────────────
gem "blueprinter", "~> 1.0"

# ── Paginação ─────────────────────────────────────────────────────────────────
gem "pagy", "~> 9.3"

# ── Upload S3 (ativo quando STORAGE=s3) ──────────────────────────────────────
gem "aws-sdk-s3", require: false

# ── Exportação PDF ────────────────────────────────────────────────────────────
gem "prawn",       "~> 2.5", require: false
gem "prawn-table", "~> 0.2", require: false

# ── OpenAPI / Swagger docs ────────────────────────────────────────────────────
gem "rswag-api",  "~> 2.16"
gem "rswag-ui",   "~> 2.16"

# ── SSO / SAML ────────────────────────────────────────────────────────────────
gem "ruby-saml",  "~> 1.16"

# ── Métricas Prometheus ───────────────────────────────────────────────────────
gem "prometheus-client", "~> 4.2"

# ── Monitoramento ─────────────────────────────────────────────────────────────
gem "sentry-ruby"
gem "sentry-rails"

# E-mail via MailerSend HTTP API — sem gem extra (Net::HTTP nativo)

group :development, :test do
  gem "dotenv-rails"
  gem "rspec-rails",       "~> 7.0"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker",             "~> 3.4"
  gem "shoulda-matchers",  "~> 6.0"
  gem "simplecov",         require: false
  gem "webmock",           "~> 3.0"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
end

group :development do
  gem "brakeman",              require: false
  gem "bundler-audit",         require: false
  gem "rubocop-rails-omakase", require: false
end
