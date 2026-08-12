class HealthController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def show
    render json: {
      status: "ok",
      env: Rails.env,
      time: Time.current.iso8601,
      database: database_ok?,
      redis: redis_ok?,
      ai_service: AppConfig.ai_enabled? ? AiClient.new.healthy? : "disabled"
    }
  end

  private

  def database_ok?
    ActiveRecord::Base.connection.execute("SELECT 1") && true
  rescue StandardError
    false
  end

  def redis_ok?
    Sidekiq.redis { |conn| conn.call("PING") } == "PONG"
  rescue StandardError
    false
  end
end
