# One JSON error envelope for the whole API.
#
# The React client reads two shapes:
#   err.response.data.errors  -> array of strings (form validation)
#   err.response.data.error   -> single string   (toasts / banners)
# Both are always present so either read works.
module ErrorHandling
  extend ActiveSupport::Concern

  class Forbidden < StandardError; end
  class Unauthorized < StandardError; end

  included do
    rescue_from StandardError,                       with: :render_internal_error
    rescue_from ActiveRecord::RecordNotFound,        with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid,         with: :render_record_invalid
    rescue_from ActionController::ParameterMissing,  with: :render_parameter_missing
    rescue_from ArgumentError,                       with: :render_bad_request
    rescue_from Unauthorized,                        with: :render_unauthorized
    rescue_from Forbidden,                           with: :render_forbidden
    rescue_from JsonWebToken::InvalidToken,          with: :render_unauthorized
  end

  def render_errors(messages, status: :unprocessable_entity)
    messages = Array(messages).map(&:to_s)
    render json: { errors: messages, error: messages.first }, status: status
  end

  private

  def render_record_invalid(exception)
    render_errors(exception.record&.error_messages || exception.message)
  end

  def render_not_found(exception)
    message = exception.is_a?(String) ? exception : I18n.t("errors.not_found")
    render_errors(message, status: :not_found)
  end

  def render_parameter_missing(exception)
    render_errors("Missing parameter: #{exception.param}", status: :bad_request)
  end

  def render_bad_request(exception)
    render_errors(exception.message, status: :bad_request)
  end

  def render_unauthorized(exception = nil)
    render_errors(exception&.message.presence || I18n.t("errors.unauthorized"), status: :unauthorized)
  end

  def render_forbidden(exception = nil)
    render_errors(exception&.message.presence || I18n.t("errors.forbidden"), status: :forbidden)
  end

  def render_internal_error(exception)
    raise exception if Rails.env.local?

    Rails.logger.error("[500] #{exception.class}: #{exception.message}")
    Rails.logger.error(exception.backtrace&.first(20)&.join("\n"))
    render_errors("Something went wrong on our side", status: :internal_server_error)
  end
end
