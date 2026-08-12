class VirtualTryonJob < ApplicationJob
  queue_as :ai

  def perform(virtual_tryon_id)
    tryon = VirtualTryon.find_by(id: virtual_tryon_id)
    return if tryon.blank?

    VirtualTryonProcessor.call(tryon)
  rescue VirtualTryonProcessor::ProcessingError => e
    Rails.logger.error("[job] try-on failed for ##{virtual_tryon_id}: #{e.message}")
  end
end
