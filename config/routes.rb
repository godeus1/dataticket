Rails.application.routes.draw do
  # Prometheus scraping (sem autenticação — proteger via IP no reverse proxy)
  get "/metrics", to: "metrics#index"

  # Swagger / OpenAPI UI
  # Em produção só é exposto se API_DOCS_ENABLED=true estiver definido no Railway.
  # Isso evita vazar o contrato da API publicamente.
  if !Rails.env.production? || ENV["API_DOCS_ENABLED"] == "true"
    mount Rswag::Ui::Engine => "/api-docs"
    mount Rswag::Api::Engine => "/api-docs"
  end

  # Rails built-in health check
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users,
    path: "api/v1",
    path_names: { sign_in: "login", sign_out: "logout" },
    controllers: { sessions: "api/v1/sessions" },
    skip: %i[registrations passwords confirmations unlocks]

  namespace :api do
    namespace :v1 do
      # Health check
      get "health", to: "health#index"

      # Reset de senha público (fluxo "esqueci minha senha")
      post "password_reset_request", to: "password_resets#request_reset"
      post "password_reset_confirm", to: "password_resets#create"

      # Perfil do usuário autenticado
      get "me", to: "users#me"

      # CSAT (público)
      post "csat/:token", to: "csat#submit", as: :csat_submit

      # SSO / SAML (público — sem JWT)
      get  "sso/init",     to: "sso#init"
      post "sso/callback", to: "sso#callback"

      # Tickets
      resources :tickets do
        resources :comments,    only: %i[index create destroy], module: :tickets
        resources :attachments, only: %i[index create destroy], module: :tickets do
          member { get :download }
        end
        collection do
          post :bulk_triage
          get  :trash
        end
        member do
          patch :triage
          patch :change_status
          patch :assign
          get   :histories
          patch :restore
          delete :purge
        end
      end

      # Usuários
      resources :users do
        member do
          patch :toggle_active
          post  :reset_password
        end
      end

      # Configurações
      resources :categories
      resources :priorities
      resources :queues do
        member do
          post   :add_member
          delete :remove_member
        end
      end
      resources :holidays
      resources :articles

      # Notificações
      resources :notifications, only: %i[index update] do
        collection { patch :mark_all_read }
      end

      # Relatórios e Auditoria
      resources :audit_logs, only: %i[index]
      resources :reports,    only: %i[index] do
        collection { get :export }
      end

      # Organização (single resource)
      resource :organization, only: %i[show update]

      # ── Fase 4: Automação e Inteligência ──────────────────────────────────
      resources :triage_rules
      resources :webhook_endpoints do
        member { post :test_delivery }
      end
      resources :sla_policies

      # ── Fase 5 (tags/custom_fields — implementados anteriormente) ─────────
      resources :tags
      resources :custom_fields

      # ── Fase 5: Escala e Governança ───────────────────────────────────────
      # Multi-org / MSP
      resources :accounts do
        member { get :organizations }
      end

      # SSO configuration (autenticado — admin only)
      resource :sso_configuration, only: %i[show create update destroy]

      # Event sourcing audit trail
      resources :events, only: %i[index]
    end
  end
end
