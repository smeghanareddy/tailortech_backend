# The Python service may hand back either an inline base64 payload or a URL
# (Replicate / Hugging Face outputs are usually URLs). Both end up as an Active
# Storage attachment so the frontend always gets a stable, CDN-served link.
class ImageIngestor
  class UnsupportedPayload < StandardError; end

  DATA_URI = %r{\Adata:(?<type>image/[a-z0-9.+-]+);base64,(?<data>.+)\z}im

  def self.attach!(attachment, payload:, filename:)
    new(payload: payload, filename: filename).attach_to(attachment)
  end

  def initialize(payload:, filename:)
    @payload = payload
    @filename = filename
  end

  def attach_to(attachment)
    blob = build_blob
    attachment.attach(blob)
    attachment
  end

  private

  attr_reader :payload, :filename

  def build_blob
    if payload.is_a?(Hash)
      from_hash(payload.with_indifferent_access)
    elsif payload.is_a?(String)
      from_string(payload)
    else
      raise UnsupportedPayload, "Cannot ingest #{payload.class}"
    end
  end

  def from_hash(hash)
    base64 = hash[:image_base64] || hash[:base64] || hash[:image]
    return from_base64(base64, hash[:content_type]) if base64.present?

    url = hash[:image_url] || hash[:url]
    return from_url(url) if url.present?

    raise UnsupportedPayload, "Response contained no image_base64 or image_url"
  end

  def from_string(string)
    if (match = DATA_URI.match(string.strip))
      from_base64(match[:data], match[:type])
    elsif string.start_with?("http://", "https://")
      from_url(string)
    else
      from_base64(string, nil)
    end
  end

  def from_base64(data, content_type)
    clean = data.to_s.sub(DATA_URI) { Regexp.last_match(:data) }
    binary = Base64.decode64(clean)
    raise UnsupportedPayload, "Decoded image was empty" if binary.blank?

    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(binary),
      filename: filename,
      content_type: content_type.presence || "image/png"
    )
  end

  def from_url(url)
    response = Faraday.new do |f|
      f.options.timeout = AppConfig.ai_timeout
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end.get(url)

    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(response.body),
      filename: filename,
      content_type: response.headers["content-type"].presence || "image/png"
    )
  rescue Faraday::Error => e
    raise UnsupportedPayload, "Could not download generated image: #{e.message}"
  end
end
