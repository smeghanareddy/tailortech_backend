module Api
  module V1
    module Designer
      class CustomerMeasurementsController < BaseController
        before_action :require_designer!
        before_action :set_customer
        before_action :set_measurement, only: %i[update destroy]

        # GET /api/v1/designer/customers/:customer_id/measurements
        def index
          render json: MeasurementSerializer.collection(@customer.measurements.recent)
        end

        # POST /api/v1/designer/customers/:customer_id/measurements
        #
        # The inline form sends `measurement_name` plus the numeric fields and
        # prepends the returned object to its list, so this responds with the
        # single measurement rather than the collection.
        def create
          measurement = @customer.measurements.new(measurement_params)
          measurement.created_by = current_user
          measurement.source = "designer"

          if measurement.save
            @link.touch_activity!
            render json: MeasurementSerializer.call(measurement), status: :created
          else
            render_errors(measurement.error_messages)
          end
        end

        # PATCH /api/v1/designer/customers/:customer_id/measurements/:id
        def update
          if @measurement.update(measurement_params)
            render json: MeasurementSerializer.call(@measurement)
          else
            render_errors(@measurement.error_messages)
          end
        end

        # DELETE /api/v1/designer/customers/:customer_id/measurements/:id
        def destroy
          @measurement.destroy!
          head :no_content
        end

        private

        def set_customer
          @link = current_user.designer_customers.find_by!(customer_id: params[:customer_id])
          @customer = @link.customer
        end

        def set_measurement
          @measurement = @customer.measurements.find(params[:id])
        end

        def measurement_params
          values = Measurement::FIELDS.index_with { |field| params[field].presence }
          values[:name] = params[:measurement_name].presence || params[:name].presence ||
                          "Measurements #{Date.current.strftime('%b %Y')}"
          values[:notes] = params[:notes] if params.key?(:notes)
          values
        end
      end
    end
  end
end
