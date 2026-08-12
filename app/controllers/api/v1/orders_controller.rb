module Api
  module V1
    class OrdersController < BaseController
      before_action :set_order, only: %i[show update]

      # GET /api/v1/orders
      def index
        scope = if current_user.designer_or_admin? && boolean_param(:assigned)
                  Order.where(designer_id: current_user.id)
                else
                  current_user.orders
                end

        render json: OrderSerializer.collection(scope.includes(:dress_design, :boutique).recent)
      end

      # GET /api/v1/orders/:id
      def show
        render json: OrderSerializer.detail(@order)
      end

      # POST /api/v1/orders
      def create
        design = DressDesign.where(user_id: current_user.id)
                            .or(DressDesign.where(designer_id: current_user.id))
                            .find(params[:dress_design_id])

        order = current_user.orders.new(order_params)
        order.dress_design = design
        order.measurement = current_user.measurements.find_by(id: params[:measurement_id]) ||
                            current_user.measurements.recent.first
        order.designer ||= design.designer

        if order.save
          design.ordered!
          render json: OrderSerializer.detail(order), status: :created
        else
          render_errors(order.error_messages)
        end
      end

      # PATCH /api/v1/orders/:id — customers may cancel, designers may advance.
      def update
        if params[:status].present? && !allowed_transition?(params[:status])
          return render_errors("You cannot move this order to #{params[:status]}", status: :forbidden)
        end

        if @order.update(order_params.merge(status_update))
          render json: OrderSerializer.detail(@order)
        else
          render_errors(@order.error_messages)
        end
      end

      private

      def set_order
        @order = Order.where(user_id: current_user.id)
                      .or(Order.where(designer_id: current_user.id))
                      .find(params[:id])
      end

      def order_params
        params.permit(:boutique_id, :designer_id, :notes, :expected_delivery_on,
                      :delivery_address_line, :delivery_city, :delivery_state,
                      :delivery_pincode, :contact_phone, :price)
      end

      def status_update
        return {} if params[:status].blank?

        { status: params[:status] }
      end

      def allowed_transition?(status)
        return true if current_user.super_admin?
        return true if current_user.designer_or_admin? && @order.designer_id == current_user.id

        status.to_s == "cancelled" && @order.user_id == current_user.id
      end
    end
  end
end
