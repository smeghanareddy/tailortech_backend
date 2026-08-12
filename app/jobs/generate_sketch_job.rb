# Async variant of the sketch call. The studio hits the synchronous endpoint,
# but bulk regeneration (e.g. after a library asset changes) goes through here.
class GenerateSketchJob < ApplicationJob
  queue_as :ai

  def perform(dress_design_id)
    design = DressDesign.find_by(id: dress_design_id)
    return if design.blank?

    SketchGenerator.call(design)
  rescue SketchGenerator::GenerationError => e
    Rails.logger.error("[job] sketch failed for design ##{dress_design_id}: #{e.message}")
  end
end
