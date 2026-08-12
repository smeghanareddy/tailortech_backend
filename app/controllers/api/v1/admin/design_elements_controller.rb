module Api
  module V1
    module Admin
      # Super Admin → Design Library.
      #
      # Upload image → extract outer boundary → remove background →
      # transparent asset → assign category → assign compatibility → publish.
      # The heavy steps run in ProcessDesignAssetJob on the `assets` queue.
      class DesignElementsController < BaseController
        before_action :set_element, only: %i[show update destroy publish unpublish reprocess]

        # GET /api/v1/admin/design_elements?category=neck&status=pending
        def index
          scope = DesignElement.all
          scope = scope.in_category(params[:category]) if params[:category].present?
          scope = scope.where(published: boolean_param(:published)) if params.key?(:published)
          scope = scope.where(processing_status: params[:status]) if params[:status].present?

          render json: scope.search(params[:q]).ordered.map { |e| DesignElementSerializer.detail(e) }
        end

        # GET /api/v1/admin/design_elements/:id
        def show
          render json: DesignElementSerializer.detail(@element)
        end

        # POST /api/v1/admin/design_elements   (multipart)
        #
        # `source_image` is the raw upload; front/back/shadow may be supplied
        # directly when an asset has already been cut out elsewhere.
        def create
          element = DesignElement.new(element_params)
          element.created_by = current_user

          if element.save
            attach_layers(element)
            enqueue_processing(element)
            render json: DesignElementSerializer.detail(element), status: :created
          else
            render_errors(element.error_messages)
          end
        end

        # PATCH /api/v1/admin/design_elements/:id
        def update
          if @element.update(element_params)
            attach_layers(@element)
            enqueue_processing(@element) if params[:source_image].present?
            render json: DesignElementSerializer.detail(@element)
          else
            render_errors(@element.error_messages)
          end
        end

        # DELETE /api/v1/admin/design_elements/:id
        def destroy
          @element.destroy!
          head :no_content
        end

        # POST /api/v1/admin/design_elements/:id/publish
        def publish
          unless @element.front_image.attached? || @element.image_url.present?
            return render_errors("Attach or process a front layer before publishing")
          end

          @element.update!(published: true)
          render json: DesignElementSerializer.detail(@element)
        end

        # POST /api/v1/admin/design_elements/:id/unpublish
        def unpublish
          @element.update!(published: false)
          render json: DesignElementSerializer.detail(@element)
        end

        # POST /api/v1/admin/design_elements/:id/reprocess
        def reprocess
          return render_errors("No source image to reprocess") unless @element.source_image.attached?

          ProcessDesignAssetJob.perform_later(@element.id)
          render json: DesignElementSerializer.detail(@element), status: :accepted
        end

        private

        def set_element
          @element = DesignElement.find(params[:id])
        end

        def element_params
          attrs = params.permit(:category, :name, :slug, :description, :image_url,
                                :z_index, :sort_order, :color_zone, :opacity)
                        .to_h.compact_blank

          # Booleans go through cast so an explicit `false` is not swallowed.
          %i[supports_color published].each do |flag|
            attrs[flag.to_s] = ActiveModel::Type::Boolean.new.cast(params[flag]) if params.key?(flag)
          end

          metadata = params[:metadata]
          parsed = metadata.is_a?(ActionController::Parameters) ? metadata.to_unsafe_h
                                                                : parse_metadata(metadata)
          attrs["metadata"] = parsed if parsed.present?
          attrs
        end

        def parse_metadata(value)
          return nil if value.blank?

          JSON.parse(value.to_s)
        rescue JSON::ParserError
          nil
        end

        def attach_layers(element)
          {
            source_image: params[:source_image],
            front_image: params[:front_image],
            back_image: params[:back_image],
            shadow_image: params[:shadow_image],
            thumbnail: params[:thumbnail]
          }.each do |slot, file|
            next if file.blank?

            element.public_send(slot).attach(file)
          end
        end

        def enqueue_processing(element)
          return unless element.source_image.attached?
          return if element.front_image.attached? && params[:front_image].present?

          ProcessDesignAssetJob.perform_later(element.id)
        end
      end
    end
  end
end
