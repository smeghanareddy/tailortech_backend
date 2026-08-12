# Central place for the handful of environment-driven settings the app needs.
# Loaded before CORS, so it lives in app/lib-independent land (plain module here).
module AppConfig
  module_function

  # Absolute host used when building Active Storage URLs outside a request
  # (jobs, serializers, the layer composer).
  def host
    ENV.fetch("APP_HOST", "http://localhost:3000")
  end

  def frontend_url
    ENV.fetch("FRONTEND_URL", "http://localhost:5173")
  end

  def allowed_origins
    ENV.fetch("ALLOWED_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173")
       .split(",").map(&:strip).reject(&:empty?)
  end

  # ── Python AI service (FastAPI + PyTorch/OpenCV/Replicate/HuggingFace) ──
  def ai_service_url
    ENV.fetch("AI_SERVICE_URL", "http://localhost:8000")
  end

  def ai_service_token
    ENV["AI_SERVICE_TOKEN"]
  end

  def ai_enabled?
    ENV.fetch("AI_SERVICE_ENABLED", "false") == "true"
  end

  def ai_timeout
    ENV.fetch("AI_SERVICE_TIMEOUT", 60).to_i
  end

  # ── JWT ──
  def jwt_secret
    ENV["JWT_SECRET"].presence || Rails.application.secret_key_base
  end

  def jwt_ttl
    ENV.fetch("JWT_TTL_HOURS", 24 * 14).to_i.hours
  end

  # ── Layer rendering engine ──
  def preview_cache_ttl
    ENV.fetch("PREVIEW_CACHE_TTL_SECONDS", 3600).to_i.seconds
  end

  def cdn_host
    ENV["CDN_HOST"].presence
  end
end

Rails.application.routes.default_url_options[:host] = AppConfig.host
