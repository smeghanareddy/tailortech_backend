# The React app runs on a different origin (Vite dev server / CDN in prod).
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*AppConfig.allowed_origins)

    resource "*",
             headers: :any,
             expose: %w[Authorization X-Total-Count X-Page X-Per-Page],
             methods: %i[get post put patch delete options head],
             max_age: 600
  end
end
