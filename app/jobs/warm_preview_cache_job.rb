# Pre-renders the layer manifests for the most-used combinations so the studio
# hits a warm Redis key instead of composing on first click.
class WarmPreviewCacheJob < ApplicationJob
  queue_as :low

  def perform(limit = 200)
    DressDesign.recent.limit(limit).find_each do |design|
      selection = DressDesignSerializer.selection_for(design)
      LayerComposer::VIEWS.each { |view| LayerComposer.call(selection: selection, view: view) }
    end
  end
end
