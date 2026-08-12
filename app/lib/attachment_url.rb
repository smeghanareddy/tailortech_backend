# Builds absolute Active Storage URLs from anywhere — controllers, jobs,
# serializers — without depending on a request being in flight.
#
# When CDN_HOST is set (CloudFront in front of the S3 bucket) the blob path is
# rewritten onto the CDN so assets are delivered from the edge.
module AttachmentUrl
  module_function

  def call(attachment)
    return nil if attachment.blank?
    return nil unless attachment.respond_to?(:attached?) && attachment.attached?

    url = Rails.application.routes.url_helpers.rails_blob_url(attachment, host: AppConfig.host)
    rewrite_to_cdn(url)
  rescue StandardError => e
    Rails.logger.warn("[attachment_url] could not build url: #{e.class}: #{e.message}")
    nil
  end

  def variant(attachment, transformations)
    return nil unless attachment.respond_to?(:attached?) && attachment.attached?
    return call(attachment) unless attachment.variable?

    url = Rails.application.routes.url_helpers.rails_representation_url(
      attachment.variant(transformations).processed, host: AppConfig.host
    )
    rewrite_to_cdn(url)
  rescue StandardError => e
    Rails.logger.warn("[attachment_url] variant failed: #{e.class}: #{e.message}")
    call(attachment)
  end

  def rewrite_to_cdn(url)
    cdn = AppConfig.cdn_host
    return url if cdn.blank? || url.blank?

    uri = URI.parse(url)
    cdn_uri = URI.parse(cdn.start_with?("http") ? cdn : "https://#{cdn}")
    uri.scheme = cdn_uri.scheme
    uri.host   = cdn_uri.host
    uri.port   = cdn_uri.port
    uri.to_s
  rescue URI::InvalidURIError
    url
  end
end
