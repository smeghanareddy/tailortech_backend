module Api
  module V1
    class VirtualTryonsController < BaseController
      before_action :set_tryon, only: %i[show destroy]

      # GET /api/v1/virtual_tryons
      def index
        render json: VirtualTryonSerializer.collection(
          current_user.virtual_tryons.includes(:dress_design).recent.limit(40)
        )
      end

      # GET /api/v1/virtual_tryons/:id
      def show
        render json: VirtualTryonSerializer.call(@tryon)
      end

      # POST /api/v1/virtual_tryons   (multipart)
      #
      # The garment comes from either:
      #   dress_design_id — one of the customer's saved designs, or
      #   garment_url     — an image linked from another website
      def create
        photo = params[:photo]
        return render_errors("Upload a photo to try the design on", status: :bad_request) if photo.blank?

        link = params[:garment_url].presence
        design = link ? nil : readable_design(params[:dress_design_id])

        tryon = current_user.virtual_tryons.new(
          dress_design: design,
          measurement: current_user.measurements.recent.first
        )
        tryon.source_photo.attach(photo)

        if link
          begin
            fetched = RemoteImageFetcher.call(link)
          rescue RemoteImageFetcher::FetchError => e
            return render_errors(e.message, status: :unprocessable_entity)
          end

          # Copy it into our storage — the other site may change or remove it.
          tryon.garment_image.attach(io: fetched.io, filename: fetched.filename,
                                     content_type: fetched.content_type)
          tryon.garment_source_url = fetched.final_url
          tryon.garment_source_site = fetched.host
        end

        return render_errors(tryon.error_messages) unless tryon.save

        if boolean_param(:async)
          VirtualTryonJob.perform_later(tryon.id)
          return render json: VirtualTryonSerializer.call(tryon), status: :accepted
        end

        VirtualTryonProcessor.call(tryon)
        render json: VirtualTryonSerializer.call(tryon.reload), status: :created
      rescue VirtualTryonProcessor::ProcessingError => e
        render json: { error: e.message, errors: [e.message] }, status: :service_unavailable
      end

      # DELETE /api/v1/virtual_tryons/:id
      def destroy
        @tryon.destroy!
        head :no_content
      end

      private

      def set_tryon
        @tryon = current_user.virtual_tryons.find(params[:id])
      end

      def readable_design(id)
        DressDesign.where(user_id: current_user.id)
                   .or(DressDesign.where(designer_id: current_user.id))
                   .or(DressDesign.where(public_portfolio: true))
                   .find(id)
      end
    end
  end
end
