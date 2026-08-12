module Api
  module V1
    class MeasurementsController < BaseController
      before_action :set_measurement, only: %i[show update destroy]

      # GET /api/v1/measurements
      def index
        render json: MeasurementSerializer.collection(current_user.measurements.recent)
      end

      # GET /api/v1/measurements/:id
      def show
        render json: MeasurementSerializer.call(@measurement)
      end

      # POST /api/v1/measurements
      def create
        measurement = current_user.measurements.new(measurement_params)
        measurement.created_by = current_user

        if measurement.save
          render json: MeasurementSerializer.call(measurement), status: :created
        else
          render_errors(measurement.error_messages)
        end
      end

      # PUT/PATCH /api/v1/measurements/:id
      def update
        if @measurement.update(measurement_params)
          render json: MeasurementSerializer.call(@measurement)
        else
          render_errors(@measurement.error_messages)
        end
      end

      # DELETE /api/v1/measurements/:id
      def destroy
        @measurement.destroy!
        head :no_content
      end

      # POST /api/v1/measurements/estimate_from_photo   (multipart)
      #
      # Returns `{ estimated: { height: .., bust: .. } }` — the form pre-fills
      # from it, the user adjusts, then saves through #create.
      def estimate_from_photo
        photo = params[:photo]
        return render_errors("Upload a front-view photo", status: :bad_request) if photo.blank?

        result = MeasurementEstimator.call(photo: photo, height_hint: params[:height])
        render json: result
      rescue MeasurementEstimator::EstimationError => e
        render json: { error: e.message, errors: [e.message], estimated: {} },
               status: :service_unavailable
      end

      private

      def set_measurement
        @measurement = current_user.measurements.find(params[:id])
      end

      def measurement_params
        permitted = params.permit(:name, :unit, :notes, :source, :ai_estimated,
                                  *Measurement::FIELDS).to_h

        # Empty strings from the number inputs mean "not measured", not zero.
        Measurement::FIELDS.each do |field|
          permitted[field.to_s] = nil if permitted[field.to_s].blank?
        end

        permitted["name"] = permitted["name"].presence || "My Measurements"
        permitted.delete("source") if permitted["source"].blank?
        permitted.delete("unit") if permitted["unit"].blank?

        if permitted.key?("ai_estimated")
          permitted["ai_estimated"] = ActiveModel::Type::Boolean.new.cast(permitted["ai_estimated"])
          permitted["source"] ||= "ai_photo" if permitted["ai_estimated"]
        end

        permitted
      end
    end
  end
end
