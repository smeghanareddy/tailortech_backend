require "faraday"
require "faraday/multipart"

# Thin HTTP client for the Python AI service (FastAPI + PyTorch / OpenCV /
# Replicate / Hugging Face).
#
# Expected endpoints on the Python side:
#   POST /sketch                 { design: {...} }            -> { image_url | image_base64 }
#   POST /tryon                  multipart photo + design     -> { image_url | image_base64, landmarks }
#   POST /measurements/estimate  multipart photo              -> { measurements: {...}, confidence }
#   POST /assets/process         multipart image              -> { front_base64, back_base64, shadow_base64 }
class AiClient
  class Error < StandardError; end
  class Unavailable < Error; end
  class RequestFailed < Error
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

  # Statuses the Python service uses to say "not available right now".
  UNAVAILABLE_STATUSES = [503, 504].freeze

  def initialize(base_url: AppConfig.ai_service_url, token: AppConfig.ai_service_token,
                 timeout: AppConfig.ai_timeout)
    @base_url = base_url
    @token = token
    @timeout = timeout
  end

  def enabled?
    AppConfig.ai_enabled?
  end

  def generate_sketch(payload)
    post_json("/sketch", payload)
  end

  # Flatten a layer manifest into one image, locally on the Python side.
  # Needs no API key — this is the spec's "Layer Merge → Final Preview" step,
  # not a generative call.
  def compose(layers:, width: nil, height: nil, background: nil)
    post_json("/compose", {
      layers: layers, width: width, height: height, background: background
    }.compact)
  end

  def virtual_tryon(photo_io:, filename:, content_type:, design:)
    post_multipart("/tryon",
                   photo: upload(photo_io, filename, content_type),
                   design: design.to_json)
  end

  def estimate_measurements(photo_io:, filename:, content_type:, height_hint: nil)
    params = { photo: upload(photo_io, filename, content_type) }
    params[:height_hint] = height_hint.to_s if height_hint.present?
    post_multipart("/measurements/estimate", params)
  end

  def process_asset(image_io:, filename:, content_type:, category:)
    post_multipart("/assets/process",
                   image: upload(image_io, filename, content_type),
                   category: category.to_s)
  end

  def healthy?
    connection.get("/health").success?
  rescue StandardError
    false
  end

  private

  attr_reader :base_url, :token, :timeout

  def upload(io, filename, content_type)
    Faraday::Multipart::FilePart.new(io, content_type.presence || "application/octet-stream", filename)
  end

  def post_json(path, payload)
    handle { connection.post(path, payload.to_json, "Content-Type" => "application/json") }
  end

  def post_multipart(path, params)
    handle { multipart_connection.post(path, params) }
  end

  def handle
    raise Unavailable, "AI service is disabled (AI_SERVICE_ENABLED=false)" unless enabled?

    response = yield
    unless response.success?
      # The Python service answers 503 when no provider is configured for an
      # endpoint, and 504 when an upstream model times out. Both mean "the AI
      # cannot serve this right now", so they map to Unavailable and callers
      # fall back to library assets rather than losing the user's work.
      # A 502 means a provider was reached and genuinely failed — that stays
      # a hard error so it surfaces instead of being masked by a fallback.
      if UNAVAILABLE_STATUSES.include?(response.status)
        raise Unavailable, "AI service unavailable (#{response.status}): #{error_message(response)}"
      end

      raise RequestFailed.new("AI service responded with #{response.status}",
                              status: response.status, body: response.body)
    end

    parse(response.body)
  rescue Faraday::TimeoutError => e
    raise Unavailable, "AI service timed out after #{timeout}s (#{e.message})"
  rescue Faraday::ConnectionFailed => e
    raise Unavailable, "AI service unreachable at #{base_url} (#{e.message})"
  end

  # The service replies { "error": ..., "code": ..., "detail": ... }.
  def error_message(response)
    body = response.body
    body = JSON.parse(body) if body.is_a?(String) && body.start_with?("{")
    return body.to_s.truncate(200) unless body.is_a?(Hash)

    [body["error"], body["detail"]].compact_blank.join(" — ").presence ||
      body.to_s.truncate(200)
  rescue JSON::ParserError
    response.body.to_s.truncate(200)
  end

  def parse(body)
    return body if body.is_a?(Hash)

    JSON.parse(body.to_s).with_indifferent_access
  rescue JSON::ParserError
    raise RequestFailed.new("AI service returned a non-JSON response", body: body)
  end

  def connection
    @connection ||= build_connection
  end

  def multipart_connection
    @multipart_connection ||= build_connection do |f|
      f.request :multipart
      f.request :url_encoded
    end
  end

  def build_connection
    Faraday.new(url: base_url) do |f|
      f.options.timeout = timeout
      f.options.open_timeout = [timeout, 10].min
      f.headers["Authorization"] = "Bearer #{token}" if token.present?
      f.headers["Accept"] = "application/json"
      yield f if block_given?
      f.response :json, content_type: /\bjson$/
      f.adapter Faraday.default_adapter
    end
  end
end
