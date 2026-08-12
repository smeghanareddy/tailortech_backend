require_relative "boot"

require "rails"

require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module TailorTech
  class Application < Rails::Application
    config.load_defaults 7.1

    # API-only: no cookies, no sessions, no view layer for HTML.
    config.api_only = true

    # Everything under app/ is autoloaded, including app/services, app/lib,
    # app/serializers and app/jobs.
    config.autoload_lib(ignore: %w[assets tasks]) if config.respond_to?(:autoload_lib)

    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc

    # AI work (sketching, try-on, asset background removal) runs on Sidekiq.
    config.active_job.queue_adapter = :sidekiq

    # Design assets live on S3 in production, on disk locally.
    config.active_storage.variant_processor = :mini_magick

    # Generators — no fixtures/helpers/assets for an API app.
    config.generators do |g|
      g.test_framework :rspec, fixture: false
      g.helper false
      g.assets false
    end
  end
end
