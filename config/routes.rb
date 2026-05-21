Rails.application.routes.draw do
  # Rails built-in health check
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users,
    path: "api/v1",
    path_names: { sign_in: "login", sign_out: "logout" },
    controllers: { sessions: "api/v1/sessions" },
    skip: %i[registrations passwords confirmations unlocks]

  namespace :api do
    namespace :v1 do
      # Health check da API
      get "health", to: "health#index"

      # Tickets
      resources :tickets do
        resources :comments,    only: %i[index create destroy], module: :tickets
        resources :attachments, only: %i[index create destroy], module: :tickets
        member do
          patch :triage
          patch :change_status
          patch :assign
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
      resources :reports,    only: %i[index]

      # Organização (single resource — Salvabras)
      resource :organization, only: %i[show update]
    end
  end
end
