require "resolv"

# Fetches an image from a user-supplied URL.
#
# Anything the user can make the server request is an SSRF vector: without
# guards, a link like http://169.254.169.254/ or http://localhost:5432 would
# have the server fetch internal resources on the attacker's behalf and hand
# back the result. So every hop is validated:
#
#   * http/https only — no file://, gopher://, data: …
#   * the resolved IP must be publicly routable (no loopback, private,
#     link-local, multicast or reserved ranges)
#   * redirects are followed manually and re-validated, with a hop cap
#   * the response must actually be an image, and under the size limit
class RemoteImageFetcher
  class FetchError < StandardError; end

  MAX_BYTES = 8 * 1024 * 1024
  MAX_REDIRECTS = 3
  TIMEOUT = 12
  ALLOWED_TYPES = %w[image/jpeg image/jpg image/png image/webp image/gif image/bmp].freeze

  Result = Struct.new(:io, :filename, :content_type, :final_url, :host, keyword_init: true)

  def self.call(...) = new(...).call

  def initialize(url)
    @url = url.to_s.strip
  end

  def call
    raise FetchError, "Enter an image link" if url.blank?

    current = parse_and_validate(url)
    response = nil

    (MAX_REDIRECTS + 1).times do
      response = request(current)

      break unless response.is_a?(Net::HTTPRedirection)

      location = response["location"]
      raise FetchError, "The link redirected without a destination" if location.blank?

      # Re-validate every hop — a public URL can redirect to an internal one.
      current = parse_and_validate(URI.join(current.to_s, location).to_s)
    end

    raise FetchError, "The link redirected too many times" if response.is_a?(Net::HTTPRedirection)

    unless response.is_a?(Net::HTTPSuccess)
      raise FetchError, "The site returned #{response.code} for that link"
    end

    validate_response!(response)

    Result.new(
      io: StringIO.new(response.body),
      filename: filename_for(current, response),
      content_type: normalized_type(response),
      final_url: current.to_s,
      host: current.host
    )
  rescue URI::InvalidURIError
    raise FetchError, "That does not look like a valid link"
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise FetchError, "The site took too long to respond"
  rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
    raise FetchError, "Could not reach that site"
  end

  private

  attr_reader :url

  def parse_and_validate(candidate)
    uri = URI.parse(candidate)

    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      raise FetchError, "Only http and https links are supported"
    end
    raise FetchError, "That link has no host" if uri.host.blank?

    verify_public_address!(uri.host)
    uri
  end

  # Resolve first, then check every address the name maps to. Checking the
  # hostname string alone would miss "internal.example.com" pointing at
  # 127.0.0.1, and DNS names that resolve to private space.
  def verify_public_address!(host)
    addresses = resolve(host)
    raise FetchError, "Could not resolve that address" if addresses.empty?

    addresses.each do |address|
      ip = IPAddr.new(address)
      next if public_ip?(ip)

      raise FetchError, "That link points to a private address, which is not allowed"
    end
  end

  def resolve(host)
    # A literal IP in the URL still has to pass the same check.
    return [host] if host.match?(Resolv::IPv4::Regex) || host.match?(Resolv::IPv6::Regex)

    Resolv.getaddresses(host)
  rescue Resolv::ResolvError
    []
  end

  def public_ip?(ip)
    return false if ip.loopback? || ip.private? || ip.link_local?
    return false if ip.ipv4? && (ip.to_i.zero? || IPAddr.new("100.64.0.0/10").include?(ip) ||
                                 IPAddr.new("192.0.0.0/24").include?(ip) ||
                                 IPAddr.new("198.18.0.0/15").include?(ip) ||
                                 IPAddr.new("224.0.0.0/4").include?(ip) ||
                                 IPAddr.new("240.0.0.0/4").include?(ip))
    return false if ip.ipv6? && (IPAddr.new("fc00::/7").include?(ip) || IPAddr.new("::/128").include?(ip))

    true
  end

  def request(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = "TailorTech/1.0 (+garment reference fetch)"
    req["Accept"] = "image/*"

    http.request(req)
  end

  def validate_response!(response)
    type = normalized_type(response)
    unless ALLOWED_TYPES.include?(type)
      raise FetchError,
            "That link is not an image (the site returned #{type.presence || 'no content type'}). " \
            "Use the direct link to the image itself, not the product page."
    end

    size = response.body&.bytesize.to_i
    raise FetchError, "That image is empty" if size.zero?
    raise FetchError, "That image is larger than #{MAX_BYTES / 1024 / 1024} MB" if size > MAX_BYTES
  end

  def normalized_type(response)
    response["content-type"].to_s.split(";").first.to_s.strip.downcase
  end

  def filename_for(uri, response)
    base = File.basename(uri.path.to_s).presence
    return base if base.present? && File.extname(base).present?

    ext = Rack::Mime::MIME_TYPES.invert[normalized_type(response)] || ".jpg"
    "garment-#{SecureRandom.hex(4)}#{ext}"
  end
end
