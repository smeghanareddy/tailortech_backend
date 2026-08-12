# Upload photo → AI detects body → estimate measurements → composited preview.
class VirtualTryonProcessor
  class ProcessingError < StandardError; end

  def self.call(...) = new(...).call

  def initialize(tryon, client: AiClient.new)
    @tryon = tryon
    @client = client
  end

  def call
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    tryon.mark_processing!

    if client.enabled?
      process_with_ai
    else
      fallback
    end

    tryon.update!(
      status: :completed,
      processing_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    )
    tryon
  rescue AiClient::Unavailable => e
    Rails.logger.warn("[tryon] AI unavailable: #{e.message}")
    fallback
    tryon.update!(status: :completed)
    tryon
  rescue StandardError => e
    tryon.mark_failed!(e.message)
    raise ProcessingError, e.message
  end

  private

  attr_reader :tryon, :client

  def process_with_ai
    response = tryon.source_photo.blob.open do |file|
      client.virtual_tryon(
        photo_io: file,
        filename: tryon.source_photo.filename.to_s,
        content_type: tryon.source_photo.content_type,
        design: design_payload
      )
    end

    ImageIngestor.attach!(tryon.result_photo,
                          payload: response,
                          filename: "tryon-#{tryon.id}.png")

    tryon.update!(
      estimated_measurements: response[:measurements] || response["measurements"] || {},
      body_landmarks: response[:landmarks] || response["landmarks"] || {}
    )
  end

  # Without the AI service there is nothing to composite onto the user's photo,
  # so the design's own sketch stands in and the record is marked accordingly.
  def fallback
    # A linked garment is already an image — show it as-is rather than
    # generating anything.
    if tryon.dress_design.blank?
      return tryon.update!(result_photo_url: tryon.garment_image_display_url,
                           error_message: nil, estimated_measurements: {})
    end

    url = tryon.dress_design.sketch_display_url ||
          SketchGenerator.call(tryon.dress_design)

    tryon.update!(result_photo_url: url,
                  error_message: nil,
                  estimated_measurements: {})
  rescue SketchGenerator::GenerationError => e
    raise ProcessingError, "Try-on preview unavailable: #{e.message}"
  end

  def design_payload
    design = tryon.dress_design

    # A linked garment has no component tree to compose — the image itself is
    # the garment, so it goes straight through as the one thing to place.
    if design.blank?
      return {
        id: nil,
        source: "external_link",
        source_site: tryon.garment_source_site,
        garment_url: tryon.garment_image_display_url,
        sketch_url: tryon.garment_image_display_url,
        layers: []
      }
    end

    {
      id: design.id,
      neck: { front: design.neck_front_type, back: design.neck_back_type_resolved },
      sleeve: design.sleeve_type,
      dress_type: design.dress_type,
      fabric: design.fabric,
      colors: { bodice: design.bodice_color, skirt: design.skirt_color },
      embroidery: design.embroidery,
      lace: design.lace,
      sketch_url: design.sketch_display_url,
      layers: LayerComposer.call(selection: DressDesignSerializer.selection_for(design)).layers
    }
  end
end
