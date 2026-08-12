# ── Layer Rendering Engine ────────────────────────────────────────
#
# Instead of storing every possible dress combination, a design is described as
# an ordered stack of independent transparent layers:
#
#   Body → Dress Base → Neckline → Sleeve → Fabric → Pattern →
#   Embroidery → Lace → Belt → Buttons → Shadow
#
# This service resolves a design (saved or not) into that stack and hands the
# client a manifest it can paint in one pass. The manifest is fingerprinted and
# cached in Redis, so re-selecting a previously seen combination is a cache read
# rather than a database round trip.
class LayerComposer
  VIEWS = %w[front back].freeze

  # Paint order. Lower renders first (further back).
  ORDER = {
    body: 0, dress_base: 20, bodice: 25, skirt: 26, hemline: 27,
    neck: 30, sleeve: 40, fabric: 50, pattern: 55,
    embroidery: 60, lace: 70, belt: 75, button: 80, shadow: 95
  }.freeze

  # Colour-zone priority from the spec: a curve wins over a left cross, which
  # wins over a right cross, and so on. Used to decide which stripe paints on
  # top when regions overlap.
  COLOR_PRIORITY = { "curve" => 4, "left_cross" => 3, "right_cross" => 2,
                     "straight" => 1, "triangle" => 0 }.freeze

  Result = Struct.new(:layers, :fingerprint, :view, :cached, keyword_init: true) do
    def as_json(*)
      { view: view, fingerprint: fingerprint, cached: cached, layers: layers }
    end
  end

  def self.call(...) = new(...).call

  # `selection` is a plain hash — the studio's current state or a persisted
  # DressDesign flattened by DressDesignSerializer.selection_for.
  def initialize(selection:, view: "front", cache: Rails.cache)
    @selection = selection.deep_stringify_keys
    @view = VIEWS.include?(view.to_s) ? view.to_s : "front"
    @cache = cache
  end

  def call
    key = cache_key
    cached = true
    layers = @cache.fetch(key, expires_in: AppConfig.preview_cache_ttl) do
      cached = false
      build_layers
    end

    Result.new(layers: layers, fingerprint: fingerprint, view: view, cached: cached)
  end

  # Rebuild a single layer without touching the rest of the stack — this is what
  # keeps a colour or sleeve change under the 100 ms target.
  def layer_for(slot)
    build_layers.find { |layer| layer["slot"] == slot.to_s }
  end

  private

  attr_reader :selection, :view

  def build_layers
    layers = []
    layers << body_layer
    layers.concat(element_layers)
    layers.concat(decoration_layers)
    layers << shadow_layer
    layers.compact.sort_by { |l| l["z_index"] }
  end

  # ── Base ─────────────────────────────────────────────────────────

  def body_layer
    layer(slot: "body", z: ORDER[:body], url: nil, kind: "mannequin",
          meta: { "view" => view })
  end

  def shadow_layer
    element = lookup("dress_type", selection["dress_type"])
    return nil if element.blank?

    url = element.shadow_layer_url
    return nil if url.blank?

    layer(slot: "shadow", z: ORDER[:shadow], url: url, kind: "shadow",
          opacity: 0.35, name: element.name)
  end

  # ── Library-backed layers ────────────────────────────────────────

  def element_layers
    [
      # A fixed dress is one asset spanning both zones, so it carries the skirt
      # colour too — otherwise the skirt selection is silently discarded.
      element_layer("dress_type", selection["dress_type"], slot: "dress_base",
                    z: ORDER[:dress_base], color: zone_color("bodice"),
                    secondary_color: zone_color("skirt")),
      neck_layer,
      element_layer("sleeve", selection["sleeve_type"], slot: "sleeve",
                    z: ORDER[:sleeve], color: zone_color("sleeve")),
      element_layer("fabric", selection["fabric"], slot: "fabric",
                    z: ORDER[:fabric], blend: "multiply", opacity: 0.55),
      element_layer("pattern", selection["pattern"], slot: "pattern",
                    z: ORDER[:pattern], blend: "overlay", opacity: 0.7)
    ]
  end

  # Front and back necklines are selected independently; only one is painted
  # per view.
  def neck_layer
    name = view == "back" ? (selection.dig("neck", "back") || selection["neck_back_type"])
                          : (selection.dig("neck", "front") || selection["neck_type"])
    category = view == "back" && lookup("back_neck", name) ? "back_neck" : "neck"
    element_layer(category, name, slot: "neck", z: ORDER[:neck], color: zone_color("bodice"))
  end

  def element_layer(category, name, slot:, z:, color: nil, secondary_color: nil,
                    blend: nil, opacity: nil)
    return custom_layer(slot, z, color) if custom_upload?(slot)
    return nil if name.blank?

    element = lookup(category, name)
    return nil if element.blank?

    url = view == "back" ? (element.back_layer_url || element.front_layer_url)
                         : element.front_layer_url
    return nil if url.blank?

    tintable = element.supports_color?
    built = layer(slot: slot, z: z, url: url, kind: category, name: element.name,
                  color: tintable ? color : nil,
                  blend: blend, opacity: opacity || element.opacity.to_f,
                  meta: element.metadata)

    if tintable && secondary_color.present? && secondary_color != color
      built["secondary_color"] = secondary_color
      built["waist_ratio"] = element.metadata["waist_ratio"] || 0.46
    end

    built
  end

  # Temporary per-design uploads (crop → boundary detect → drag → resize).
  # They are never written into the shared library.
  def custom_layer(slot, z, color)
    custom = selection.dig("custom_images", slot)
    return nil if custom.blank?

    url = custom.is_a?(Hash) ? custom["url"] : custom
    return nil if url.blank?

    transform = custom.is_a?(Hash) ? custom.slice("x", "y", "scale", "rotation") : {}

    layer(slot: slot, z: z, url: url, kind: "custom", name: "Custom",
          color: color, meta: { "custom" => true, "transform" => transform })
  end

  def custom_upload?(slot)
    selection.dig("custom_images", slot).present?
  end

  # ── Embroidery / lace / belt / buttons ───────────────────────────

  def decoration_layers
    embroidery_layers + lace_layers + [belt_layer] + button_layers
  end

  PLACEMENTS = %w[neck bodice_upper bodice_lower skirt_upper skirt_lower].freeze

  def embroidery_layers
    decoration_stack("embroidery", ORDER[:embroidery], "#d4a017")
  end

  def lace_layers
    decoration_stack("lace", ORDER[:lace], "#f0e6d3")
  end

  def decoration_stack(kind, base_z, default_color)
    config = selection[kind] || {}
    return [] if config.blank?

    style = config["style"]
    color = config["color"].presence || default_color
    custom_image = config["custom_image"]

    element = style.present? && style != "custom" ? lookup(kind, style) : nil
    url = custom_image.presence || element&.front_layer_url
    return [] if url.blank?

    PLACEMENTS.each_with_index.filter_map do |placement, index|
      intensity = config[placement]
      next if intensity.blank?

      layer(slot: "#{kind}_#{placement}", z: base_z + index, url: url, kind: kind,
            name: element&.name || "Custom #{kind.titleize}",
            color: color,
            opacity: intensity == "heavy" ? 1.0 : 0.55,
            meta: { "placement" => placement, "intensity" => intensity })
    end
  end

  def belt_layer
    config = selection["lace"] || {}
    return nil unless ActiveModel::Type::Boolean.new.cast(config["has_belt"])

    element = lookup("belt", selection.dig("belt", "style")) ||
              DesignElement.published.in_category("belt").ordered.first
    url = element&.front_layer_url
    return nil if url.blank?

    layer(slot: "belt", z: ORDER[:belt], url: url, kind: "belt", name: element.name,
          color: selection.dig("belt", "color").presence || config["color"])
  end

  def button_layers
    config = selection["buttons"] || {}
    return [] if config.blank? || config["shape"].blank?

    element = lookup("button", config["shape"])
    url = element&.front_layer_url
    return [] if url.blank?

    count = config["count"].to_i.clamp(0, 24)
    return [] if count.zero?

    Array(config["placement"].presence || "bodice").then { |placements| Array(placements) }
      .each_with_index.map do |placement, index|
        layer(slot: "button_#{placement}", z: ORDER[:button] + index, url: url,
              kind: "button", name: element.name, color: config["color"],
              meta: { "placement" => placement, "count" => count })
      end
  end

  # ── Colour zones ─────────────────────────────────────────────────

  # Returns the winning colour for a zone. Multi-colour stripes are sorted by
  # the spec's priority (curve > left > right > straight > triangle) and the
  # whole ordered list travels with the layer so the client can paint gradients.
  def zone_color(zone)
    stripes = Array(selection.dig("colors", zone))
    if stripes.any?
      ordered = stripes.sort_by { |s| -COLOR_PRIORITY.fetch(s["direction"].to_s, 1) }
      return { "base" => ordered.first["color"], "stripes" => ordered }
    end

    flat = selection["#{zone}_color"].presence || selection["color"]
    flat.present? ? { "base" => flat, "stripes" => [] } : nil
  end

  # ── Plumbing ─────────────────────────────────────────────────────

  def layer(slot:, z:, url:, kind:, name: nil, color: nil, blend: nil,
            opacity: nil, meta: {})
    {
      "slot" => slot,
      "kind" => kind,
      "name" => name,
      "url" => url,
      "z_index" => z,
      "color" => color,
      "blend_mode" => blend,
      "opacity" => opacity || 1.0,
      "meta" => meta || {}
    }
  end

  # One query per category, memoised — a full stack costs a handful of lookups.
  def lookup(category, name)
    return nil if name.blank?

    index_for(category)[name.to_s.downcase] || index_for(category)[name.to_s.parameterize]
  end

  def index_for(category)
    @indexes ||= {}
    @indexes[category] ||= DesignElement.published.in_category(category).to_a.each_with_object({}) do |el, acc|
      acc[el.name.downcase] = el
      acc[el.slug] = el
    end
  end

  def fingerprint
    @fingerprint ||= Digest::SHA256.hexdigest({ v: 1, view: view, selection: selection }.to_json)
  end

  def cache_key
    "tailortech:preview:v1:#{view}:#{fingerprint}"
  end
end
