module Api
  module V1
    module Designer
      class CustomersController < BaseController
        before_action :require_designer!
        before_action :set_link, only: %i[show update]

        # GET /api/v1/designer/customers
        def index
          links = current_user.designer_customers.includes(customer: %i[measurements dress_designs]).recent
          render json: links.map { |link| CustomerSerializer.call(link.customer, link: link) }
        end

        # GET /api/v1/designer/customers/:id
        #
        # The expanded row reads `measurements` and `designs` off this payload.
        def show
          render json: CustomerSerializer.detail(@link.customer, link: @link)
        end

        # POST /api/v1/designer/customers
        #
        # Accepts customer fields plus optional initial measurements in the same
        # flat body, which is what the Add Customer modal submits.
        def create
          customer = User.new(customer_params.merge(role: :customer))

          ActiveRecord::Base.transaction do
            customer.save!
            link = current_user.designer_customers.create!(
              customer: customer, created_by_designer: true, last_activity_at: Time.current
            )
            create_initial_measurement(customer)
            render json: CustomerSerializer.detail(customer, link: link), status: :created
          end
        rescue ActiveRecord::RecordInvalid => e
          render_errors(e.record&.error_messages || e.message)
        end

        # PATCH /api/v1/designer/customers/:id
        def update
          customer = @link.customer

          if customer.update(customer_update_params)
            @link.update(notes: params[:notes]) if params.key?(:notes)
            render json: CustomerSerializer.detail(customer, link: @link)
          else
            render_errors(customer.error_messages)
          end
        end

        private

        def set_link
          @link = current_user.designer_customers.find_by!(customer_id: params[:id])
        end

        def customer_params
          params.permit(:name, :email, :phone, :password, :city, :state)
                .to_h
                .compact_blank
                .tap { |attrs| attrs["password"] ||= SecureRandom.alphanumeric(12) }
        end

        def customer_update_params
          params.permit(:name, :phone, :city, :state).to_h.compact_blank
        end

        # Measurement fields ride along in the create form; only persist them if
        # the designer actually filled something in.
        def create_initial_measurement(customer)
          values = Measurement::FIELDS.index_with { |field| params[field].presence }.compact
          return if values.empty?

          customer.measurements.create!(
            values.merge(
              name: params[:measurement_name].presence || "Initial Measurements",
              created_by: current_user,
              source: "designer"
            )
          )
        end
      end
    end
  end
end
