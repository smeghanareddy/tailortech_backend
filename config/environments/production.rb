require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true

  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Design assets on S3, delivered through CloudFront.
  config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "amazon").to_sym

  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"),
    expires_in: 12.hours,
    error_handler: ->(method:, returning:, exception:) {
      Rails.logger.error("[cache] #{method} failed: #{exception.class} #{exception.message}")
    }
  }

  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.new(Logger.new($stdout))

  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"
  config.assume_ssl = ENV.fetch("ASSUME_SSL", "false") == "true"

  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
end
