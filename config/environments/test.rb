require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = ENV["CI"].present?

  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  config.action_dispatch.show_exceptions = :rescuable

  config.active_storage.service = :test
  config.active_job.queue_adapter = :test

  config.action_mailer.delivery_method = :test
  config.active_support.deprecation = :stderr
end
