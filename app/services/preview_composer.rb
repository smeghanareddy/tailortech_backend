# Flattens a design's layer stack into a single preview image.
#
# This is the spec's rendering path — the preview is composed from uploaded
# Design Library assets, never generated. It needs no API key: the Python
# service does the pixel work with Pillow, so it costs nothing per call and
# the output always matches exactly what the customer selected.
class PreviewComposer
  class ComposeError < StandardError; end

  def self.call(...) = new(...).call

  def initialize(design, view: "front", client: AiClient.new)
    @design = design
    @view = view
    @client = client
  end

  def call
    manifest = LayerComposer.call(
      selection: DressDesignSerializer.selection_for(design), view: view
    )

    paintable = manifest.layers.count { |layer| layer["url"].present? }
    if paintable.zero?
      raise ComposeError,
            "No layer in this design has an image yet — upload assets in the Design Library"
    end

    response = client.compose(layers: manifest.layers)

    ImageIngestor.attach!(design.preview,
                          payload: response,
                          filename: "design-#{design.id}-preview-#{view}.png")

    design.update!(preview_rendered_at: Time.current,
                   preview_fingerprint: manifest.fingerprint)

    design.reload.preview_display_url
  rescue AiClient::Error => e
    raise ComposeError, e.message
  end

  private

  attr_reader :design, :view, :client
end
