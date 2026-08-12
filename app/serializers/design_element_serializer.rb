module DesignElementSerializer
  module_function

  # Shape consumed by the Design Studio option grid: `id`, `name` and
  # `image_url` are the required keys — a null image_url makes the frontend
  # fall back to its own icon.
  def call(element)
    return nil if element.blank?

    {
      id: element.id,
      name: element.name,
      slug: element.slug,
      category: element.category,
      description: element.description,
      image_url: element.display_image_url,
      z_index: element.z_index,
      color_zone: element.color_zone,
      supports_color: element.supports_color,
      opacity: element.opacity.to_f,
      metadata: element.metadata,
      published: element.published,
      sort_order: element.sort_order
    }
  end

  # Everything the layer engine and the admin library screen need.
  def detail(element)
    return nil if element.blank?

    call(element).merge(
      front_image_url: element.front_layer_url,
      back_image_url: element.back_layer_url,
      shadow_image_url: element.shadow_layer_url,
      source_image_url: AttachmentUrl.call(element.source_image),
      processing_status: element.processing_status,
      processing_error: element.processing_error,
      created_at: element.created_at,
      updated_at: element.updated_at
    )
  end

  def collection(elements)
    Array(elements).map { |element| call(element) }
  end
end
