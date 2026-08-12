require "sidekiq/web"

Rails.application.routes.draw do
  get "/up", to: "health#show"

  # Sidekiq dashboard — protected by HTTP basic auth outside development.
  if Rails.env.development?
    mount Sidekiq::Web => "/sidekiq"
  elsif ENV["SIDEKIQ_WEB_USER"].present?
    Sidekiq::Web.use Rack::Auth::Basic do |user, password|
      ActiveSupport::SecurityUtils.secure_compare(user, ENV["SIDEKIQ_WEB_USER"]) &
        ActiveSupport::SecurityUtils.secure_compare(password, ENV["SIDEKIQ_WEB_PASSWORD"].to_s)
    end
    mount Sidekiq::Web => "/sidekiq"
  end

  namespace :api do
    namespace :v1 do
      # ── Auth ────────────────────────────────────────────────────
      post   "auth/register", to: "auth#register"
      post   "auth/login",    to: "auth#login"
      get    "auth/me",       to: "auth#me"
      patch  "auth/profile",  to: "auth#update_profile"
      delete "auth/logout",   to: "auth#logout"

      # ── Design library (read side, used by the Design Studio) ────
      resources :design_elements, only: %i[index show] do
        member do
          get :compatible          # options still selectable given this choice
        end
        collection do
          get :categories
        end
      end

      # ── Designs ─────────────────────────────────────────────────
      resources :dress_designs do
        member do
          post :generate_sketch
          post :duplicate
          get  :preview            # layer manifest for the rendering engine
        end
      end

      # Preview an *unsaved* combination straight from the studio.
      post "previews", to: "previews#create"

      # ── Measurements ────────────────────────────────────────────
      resources :measurements do
        collection do
          post :estimate_from_photo
        end
      end

      # ── Virtual try-on ──────────────────────────────────────────
      resources :virtual_tryons, only: %i[index show create destroy]

      # ── Orders ──────────────────────────────────────────────────
      resources :orders, only: %i[index show create update]

      # ── Designer boutique directory (frontend: /boutique) ───────
      get "boutique",     to: "boutique#index"
      get "boutique/:id", to: "boutique#show", as: :boutique_designer

      # ── Physical boutique locator ("Nearest Boutique") ──────────
      resources :boutiques, only: %i[index show]

      # ── Designer workspace ──────────────────────────────────────
      namespace :designer do
        resources :customers, only: %i[index show create update] do
          resources :measurements, only: %i[index create update destroy],
                                   controller: "customer_measurements"
          resources :dress_designs, only: %i[index create],
                                    controller: "customer_designs"
        end
      end

      # ── Super admin ─────────────────────────────────────────────
      namespace :admin do
        resources :design_elements do
          member do
            post :publish
            post :unpublish
            post :reprocess          # re-run background removal / layer extraction
          end
        end
        resources :compatibility_rules, only: %i[index create update destroy]
        resources :boutiques
        resources :users, only: %i[index show update]
      end
    end
  end

  # Anything else is a 404 in JSON, not an HTML error page.
  match "*unmatched", to: "application#route_not_found", via: :all,
        constraints: ->(req) { req.path.exclude?("rails/active_storage") }
end
