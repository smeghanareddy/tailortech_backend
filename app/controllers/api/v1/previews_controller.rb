module Api
  module V1
    # Live preview for an *unsaved* studio combination.
    #
    # POST /api/v1/previews
    #   { view: "front", selection: { neck: {front: "V-Neck"}, sleeve_type: ...,
    #     colors: { bodice: [{color, direction}] }, embroidery: {...} } }
    #
    # Returns the ordered layer stack. Repeat combinations come straight out of
    # Redis, which is what keeps re-renders inside the 100 ms budget.
    class PreviewsController < BaseController
      skip_before_action :authenticate_user!

      def create
        result = LayerComposer.call(selection: selection_param, view: params[:view].presence || "front")

        response.set_header("X-Preview-Cache", result.cached ? "HIT" : "MISS")
        render json: result.as_json
      end

      private

      def selection_param
        raw = params[:selection]
        return raw.to_unsafe_h if raw.is_a?(ActionController::Parameters)
        return raw if raw.is_a?(Hash)

        # Also accept the flat form the studio already builds for saving.
        params.permit(:neck_type, :neck_back_type, :sleeve_type, :dress_type,
                      :fabric, :pattern, :color, :bodice_color, :skirt_color).to_h
      end
    end
  end
end
