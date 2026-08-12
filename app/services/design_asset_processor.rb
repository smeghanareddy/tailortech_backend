# Super Admin upload pipeline:
#
#   Upload → extract outer boundary → remove background →
#   transparent asset → front / back / shadow layers → publish
#
# Runs on the `assets` Sidekiq queue because background removal is slow.
class DesignAssetProcessor
  class ProcessingError < StandardError; end

  def self.call(...) = new(...).call

  def initialize(element, client: AiClient.new)
    @element = element
    @client = client
  end

  def call
    raise ProcessingError, "No source image attached" unless element.source_image.attached?

    element.mark_processing!

    if client.enabled?
      process_with_ai
    else
      # Without the AI service the upload is still usable: the original becomes
      # the front layer as-is and an admin can replace it later.
      copy_source_to_front
    end

    build_thumbnail
    element.mark_ready!
    element
  rescue AiClient::Unavailable => e
    Rails.logger.warn("[asset] AI unavailable, using raw upload: #{e.message}")
    copy_source_to_front
    build_thumbnail
    element.mark_ready!
    element
  rescue StandardError => e
    element.mark_failed!(e.message)
    raise ProcessingError, e.message
  end

  private

  attr_reader :element, :client

  def process_with_ai
    response = element.source_image.blob.open do |file|
      client.process_asset(
        image_io: file,
        filename: element.source_image.filename.to_s,
        content_type: element.source_image.content_type,
        category: element.category
      )
    end

    attach_layer(element.front_image,  response[:front_base64]  || response["front_base64"],  "front")
    attach_layer(element.back_image,   response[:back_base64]   || response["back_base64"],   "back")
    attach_layer(element.shadow_image, response[:shadow_base64] || response["shadow_base64"], "shadow")

    copy_source_to_front unless element.front_image.attached?

    bounds = response[:bounds] || response["bounds"]
    element.update!(metadata: element.metadata.merge("bounds" => bounds)) if bounds.present?
  end

  def attach_layer(attachment, payload, label)
    return if payload.blank?

    ImageIngestor.attach!(attachment, payload: payload,
                                      filename: "#{element.slug}-#{label}.png")
  end

  def copy_source_to_front
    return if element.front_image.attached?

    element.source_image.blob.open do |file|
      element.front_image.attach(
        io: file,
        filename: element.source_image.filename.to_s,
        content_type: element.source_image.content_type
      )
    end
  end

  def build_thumbnail
    return unless element.front_image.attached?
    return unless element.front_image.variable?

    element.front_image.blob.open do |file|
      element.thumbnail.attach(
        io: file,
        filename: "#{element.slug}-thumb.png",
        content_type: element.front_image.content_type
      )
    end
  rescue StandardError => e
    Rails.logger.warn("[asset] thumbnail skipped for ##{element.id}: #{e.message}")
  end
end
