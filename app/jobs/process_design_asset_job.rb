class ProcessDesignAssetJob < ApplicationJob
  queue_as :assets

  def perform(design_element_id)
    element = DesignElement.find_by(id: design_element_id)
    return if element.blank?

    DesignAssetProcessor.call(element)
  rescue DesignAssetProcessor::ProcessingError => e
    Rails.logger.error("[job] asset processing failed for element ##{design_element_id}: #{e.message}")
  end
end
