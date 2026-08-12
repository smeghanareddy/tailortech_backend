module DressDesignSerializer
  module_function

  # List shape — exactly the keys My Designs, Virtual Try-On and the boutique
  # portfolio grid read.
  def call(design)
    return nil if design.blank?

    {
      id: design.id,
      name: design.name,
      status: design.status,
      neck_type: design.neck_type,
      neck_back_type: design.neck_back_type,
      sleeve_type: design.sleeve_type,
      dress_type: design.dress_type,
      fabric: design.fabric,
      pattern: design.pattern,
      color: design.color,
      bodice_color: design.bodice_color,
      skirt_color: design.skirt_color,
      sketch_url: design.sketch_display_url,
      sketch_status: design.sketch_status,
      preview_url: design.preview_display_url,
      public_portfolio: design.public_portfolio,
      created_at: design.created_at,
      updated_at: design.updated_at
    }
  end

  def detail(design)
    return nil if design.blank?

    call(design).merge(
      components: design.components,
      bodice_colors: design.bodice_colors,
      skirt_colors: design.skirt_colors,
      embroidery: design.embroidery,
      lace: design.lace,
      buttons: design.buttons,
      custom_images: design.custom_image_urls,
      sketch_error: design.sketch_error,
      version: design.version,
      source_design_id: design.source_design_id,
      owner: { id: design.user_id, name: design.user&.name },
      designer: design.designer && { id: design.designer_id, name: design.designer.name }
    )
  end

  def collection(designs)
    Array(designs).map { |design| call(design) }
  end

  # Flattens a persisted design into the hash LayerComposer expects. The studio
  # posts the same shape for unsaved previews, so both paths share one composer.
  def selection_for(design)
    {
      "neck" => {
        "front" => design.neck_front_type,
        "back" => design.neck_back_type_resolved
      },
      "neck_type" => design.neck_type,
      "neck_back_type" => design.neck_back_type,
      "sleeve_type" => design.sleeve_type,
      "dress_type" => design.dress_type,
      "fabric" => design.fabric,
      "pattern" => design.pattern,
      "color" => design.color,
      "bodice_color" => design.bodice_color,
      "skirt_color" => design.skirt_color,
      "colors" => {
        "bodice" => design.bodice_colors,
        "skirt" => design.skirt_colors,
        "sleeve" => design.components.dig("colors", "sleeve") || []
      },
      "embroidery" => design.embroidery,
      "lace" => design.lace,
      "buttons" => design.buttons,
      "belt" => design.components["belt"] || {},
      "custom_images" => custom_image_slots(design)
    }
  end

  def custom_image_slots(design)
    urls = design.custom_image_urls
    {
      "neck" => urls[:neck],
      "sleeve" => urls[:sleeve],
      "dress_base" => urls[:dress],
      "fabric" => urls[:fabric]
    }.compact
  end
end
