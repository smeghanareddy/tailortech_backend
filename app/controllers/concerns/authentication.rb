# Stateless JWT auth: `Authorization: Bearer <token>`, exactly what
# src/lib/api.js attaches to every request.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  def current_user
    @current_user ||= begin
      payload = JsonWebToken.decode(bearer_token) if bearer_token.present?
      User.active.find_by(id: payload[:user_id]) if payload
    rescue JsonWebToken::InvalidToken
      nil
    end
  end

  def signed_in?
    current_user.present?
  end

  def authenticate_user!
    raise ErrorHandling::Unauthorized if current_user.blank?
  end

  def require_designer!
    raise ErrorHandling::Forbidden, "Designer access required" unless current_user&.designer_or_admin?
  end

  def require_super_admin!
    raise ErrorHandling::Forbidden, "Super admin access required" unless current_user&.super_admin?
  end

  private

  def bearer_token
    header = request.headers["Authorization"].to_s
    return nil unless header.start_with?("Bearer ")

    header.split(" ", 2).last.presence
  end
end
