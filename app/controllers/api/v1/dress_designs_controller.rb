module Api
  module V1
    class DressDesignsController < BaseController
      before_action :set_design, only: %i[show update destroy generate_sketch duplicate preview]
      before_action :authorize_design!, only: %i[update destroy generate_sketch duplicate]

      # GET /api/v1/dress_designs
      def index
        designs = accessible_designs
        designs = designs.where(status: params[:status]) if params[:status].present?
        designs = designs.recent

        render json: DressDesignSerializer.collection(designs)
      end

      # GET /api/v1/dress_designs/:id
      def show
        render json: DressDesignSerializer.detail(@design)
      end

      # POST /api/v1/dress_designs   (multipart/form-data)
      #
      # The Design Studio posts flat fields plus optional custom images:
      #   name, neck_type, sleeve_type, dress_type, color, fabric, status
      #   neck_image, sleeve_image, dress_image, fabric_image
      def create
        design = DressDesign.new(design_attributes)
        design.user = design_owner
        design.designer = current_user if current_user.designer_or_admin?

        if design.save
          attach_custom_images(design)
          render json: DressDesignSerializer.detail(design), status: :created
        else
          render_errors(design.error_messages)
        end
      end

      # PATCH/PUT /api/v1/dress_designs/:id
      def update
        if @design.update(design_attributes)
          attach_custom_images(@design)
          render json: DressDesignSerializer.detail(@design)
        else
          render_errors(@design.error_messages)
        end
      end

      # DELETE /api/v1/dress_designs/:id
      def destroy
        if @design.destroy
          head :no_content
        else
          render_errors(@design.error_messages, status: :conflict)
        end
      end

      # POST /api/v1/dress_designs/:id/generate_sketch
      #
      # Synchronous by design: the studio shows a spinner and expects
      # `{ sketch_url }` back in the same request.
      def generate_sketch
        url = SketchGenerator.call(@design)
        render json: { sketch_url: url, sketch_status: @design.reload.sketch_status }
      rescue SketchGenerator::GenerationError => e
        render json: { error: e.message, errors: [e.message] }, status: :service_unavailable
      end

      # POST /api/v1/dress_designs/:id/duplicate
      def duplicate
        copy = @design.dup
        copy.assign_attributes(
          name: "#{@design.name} (copy)",
          status: :draft,
          source_design_id: @design.id,
          version: @design.version + 1,
          sketch_status: "pending",
          sketch_url: nil,
          sketch_error: nil,
          sketch_generated_at: nil,
          user: current_user
        )

        if copy.save
          render json: DressDesignSerializer.detail(copy), status: :created
        else
          render_errors(copy.error_messages)
        end
      end

      # GET /api/v1/dress_designs/:id/preview?view=front
      #
      # Layer manifest for the rendering engine — the client paints the stack;
      # the server never bakes a combined image.
      def preview
        result = LayerComposer.call(
          selection: DressDesignSerializer.selection_for(@design),
          view: params[:view].presence || "front"
        )

        @design.update_column(:preview_rendered_at, Time.current)
        render json: result.as_json
      end

      private

      def set_design
        @design = DressDesign.find(params[:id])
        return if readable?(@design)

        raise ActiveRecord::RecordNotFound
      end

      def readable?(design)
        design.public_portfolio ||
          design.user_id == current_user.id ||
          design.designer_id == current_user.id ||
          current_user.super_admin?
      end

      def authorize_design!
        raise ErrorHandling::Forbidden unless @design.editable_by?(current_user)
      end

      def accessible_designs
        DressDesign.where(user_id: current_user.id)
                   .or(DressDesign.where(designer_id: current_user.id))
      end

      # A designer may save a design straight onto one of their customers.
      def design_owner
        return current_user if params[:customer_id].blank? || !current_user.designer_or_admin?

        current_user.customers.find(params[:customer_id])
      end

      def design_attributes
        # The studio sends "" for anything the user skipped; blanks are dropped
        # so they never overwrite a stored value on update.
        attrs = params.permit(
          :name, :neck_type, :neck_back_type, :sleeve_type, :dress_type,
          :fabric, :pattern, :color, :bodice_color, :skirt_color
        ).to_h.compact_blank

        # Absent status keeps whatever is stored (the column defaults to draft).
        if (status = params[:status].presence_in(DressDesign.statuses.keys))
          attrs["status"] = status
        end
        attrs["components"] = merged_components

        if params.key?(:public_portfolio)
          attrs["public_portfolio"] = ActiveModel::Type::Boolean.new.cast(params[:public_portfolio])
        end

        attrs
      end

      # `components` may arrive whole (JSON string in the multipart body) or as
      # individual JSON fields. Both are folded into one tree.
      def merged_components
        base = parse_json(params[:components])
        base = {} unless base.is_a?(Hash)

        {
          "neck" => {
            "front" => params[:neck_front_type].presence || params[:neck_type].presence,
            "back" => params[:neck_back_type].presence
          }.compact_blank,
          "colors" => {
            "bodice" => parse_json(params[:bodice_colors]) || [],
            "skirt" => parse_json(params[:skirt_colors]) || []
          },
          "embroidery" => parse_json(params[:embroidery]) || {},
          "lace" => parse_json(params[:lace]) || {},
          "buttons" => parse_json(params[:buttons]) || {},
          "belt" => parse_json(params[:belt]) || {}
        }.deep_merge(base).compact_blank
      end

      def parse_json(value)
        return nil if value.blank?
        return value.to_unsafe_h if value.is_a?(ActionController::Parameters)
        return value if value.is_a?(Hash) || value.is_a?(Array)

        JSON.parse(value.to_s)
      rescue JSON::ParserError
        nil
      end

      def attach_custom_images(design)
        {
          neck_image: params[:neck_image],
          sleeve_image: params[:sleeve_image],
          dress_image: params[:dress_image],
          fabric_image: params[:fabric_image]
        }.each do |slot, file|
          next if file.blank?

          design.public_send(slot).attach(file)
        end
      end
    end
  end
end
