module VirtualTryonSerializer
  module_function

  def call(tryon)
    return nil if tryon.blank?

    {
      id: tryon.id,
      status: tryon.status,
      dress_design_id: tryon.dress_design_id,
      design_name: tryon.dress_design&.name || tryon.garment_source_site,
      garment_source_url: tryon.garment_source_url,
      garment_source_site: tryon.garment_source_site,
      garment_image_url: tryon.garment_image_display_url,
      source_photo_url: tryon.source_photo_display_url,
      result_photo_url: tryon.result_photo_display_url,
      estimated_measurements: tryon.estimated_measurements,
      error_message: tryon.error_message,
      processing_ms: tryon.processing_ms,
      created_at: tryon.created_at
    }
  end

  def collection(tryons)
    Array(tryons).map { |t| call(t) }
  end
end
