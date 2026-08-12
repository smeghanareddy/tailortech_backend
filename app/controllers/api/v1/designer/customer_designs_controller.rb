module Api
  module V1
    module Designer
      # Designs a designer builds on behalf of one of their customers.
      class CustomerDesignsController < BaseController
        before_action :require_designer!
        before_action :set_customer

        # GET /api/v1/designer/customers/:customer_id/dress_designs
        def index
          render json: DressDesignSerializer.collection(@customer.dress_designs.recent)
        end

        # POST /api/v1/designer/customers/:customer_id/dress_designs
        def create
          design = @customer.dress_designs.new(
            params.permit(:name, :neck_type, :neck_back_type, :sleeve_type, :dress_type,
                          :fabric, :pattern, :color, :bodice_color, :skirt_color)
                  .to_h.compact_blank
          )
          design.designer = current_user
          design.status = params[:status].presence_in(DressDesign.statuses.keys) || "draft"

          if design.save
            @link.touch_activity!
            render json: DressDesignSerializer.detail(design), status: :created
          else
            render_errors(design.error_messages)
          end
        end

        private

        def set_customer
          @link = current_user.designer_customers.find_by!(customer_id: params[:customer_id])
          @customer = @link.customer
        end
      end
    end
  end
end
