# Turns a saved design into a sketch image.
#
# With the Python service running, this is a real generation call. With it
# switched off (AI_SERVICE_ENABLED=false) it degrades to the library asset for
# the chosen silhouette — never a drawn-in-code SVG, per the project spec.
class SketchGenerator
  class GenerationError < StandardError; end

  def self.call(...) = new(...).call

  def initialize(design, client: AiClient.new)
    @design = design
    @client = client
  end

  def call
    design.update!(sketch_status: "processing", sketch_error: nil)

    url = client.enabled? ? generate_with_ai : fallback_url
    raise GenerationError, "No sketch could be produced" if url.blank?

    design.update!(sketch_status: "ready", sketch_generated_at: Time.current)
    url
  rescue AiClient::Unavailable => e
    # No diffusion provider is a normal operating mode, not a failure. Compose
    # the design from its own library layers instead — that is the spec's
    # rendering path anyway, and it matches the selections exactly.
    if (url = composed_url).present?
      Rails.logger.info("[sketch] no diffusion provider, composed locally: #{e.message}")
      design.update!(sketch_status: "ready", sketch_generated_at: Time.current)
      return url
    end

    # Last resort: the library asset for the chosen silhouette.
    if (url = fallback_url).present?
      Rails.logger.warn("[sketch] AI unavailable, serving library asset: #{e.message}")
      design.update!(sketch_status: "ready", sketch_generated_at: Time.current)
      return url
    end

    # Nothing generated and nothing to stand in for it. Say which of the two
    # is actually missing — pointing only at the AI sends the operator after
    # an API token when the real gap is an empty Design Library.
    fail_design!("#{e.message}. #{no_fallback_reason}")
  rescue StandardError => e
    fail_design!(e.message)
  end

  private

  attr_reader :design, :client

  def generate_with_ai
    response = client.generate_sketch(prompt_payload)
    ImageIngestor.attach!(design.sketch,
                          payload: response,
                          filename: "design-#{design.id}-sketch.png")
    design.reload.sketch_display_url
  end

  # The AI service gets the full component tree, not a prose prompt — it decides
  # how to render each module.
  def prompt_payload
    {
      design_id: design.id,
      name: design.name,
      neck: { front: design.neck_front_type, back: design.neck_back_type_resolved },
      sleeve: design.sleeve_type,
      dress_type: design.dress_type,
      fabric: design.fabric,
      pattern: design.pattern,
      colors: {
        primary: design.color,
        bodice: design.bodice_color,
        skirt: design.skirt_color,
        bodice_stripes: design.bodice_colors,
        skirt_stripes: design.skirt_colors
      },
      embroidery: design.embroidery,
      lace: design.lace,
      buttons: design.buttons,
      custom_images: design.custom_image_urls,
      layers: LayerComposer.call(selection: DressDesignSerializer.selection_for(design)).layers
    }
  end

  # Composite the design's own layers into one image. Free, local, and the
  # result is guaranteed to reflect every selection.
  def composed_url
    PreviewComposer.call(design)
  rescue PreviewComposer::ComposeError => e
    Rails.logger.info("[sketch] local compositing unavailable: #{e.message}")
    nil
  end

  # Library asset for the selected silhouette — an existing uploaded design
  # asset, which is exactly what the spec says previews must be built from.
  def fallback_url
    @fallback_url ||= begin
      element = DesignElement.published.in_category("dress_type")
                             .where("LOWER(name) = ?", design.dress_type.to_s.downcase).first
      url = element&.display_image_url ||
            design.custom_image_urls[:dress] ||
            DesignElement.published.in_category("dress_type").ordered.first&.display_image_url

      design.update_column(:sketch_url, url) if url.present?
      url
    end
  end

  def no_fallback_reason
    silhouette = design.dress_type.presence || "this silhouette"

    if DesignElement.published.in_category("dress_type").none?
      "There are also no published dress styles in the Design Library to fall back to."
    else
      "No Design Library asset for #{silhouette} has an image attached, so there " \
        "was nothing to fall back to — upload one under Design Library → Dress Style."
    end
  end

  def fail_design!(message)
    design.update!(sketch_status: "failed", sketch_error: message.to_s.truncate(500))
    raise GenerationError, message
  end
end
