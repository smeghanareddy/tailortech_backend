module Api
  module V1
    module Admin
      class UsersController < BaseController
        before_action :set_user, only: %i[show update]

        # GET /api/v1/admin/users?role=designer&q=priya
        def index
          scope = User.all
          scope = scope.where(role: params[:role]) if params[:role].present?
          scope = scope.where("name ILIKE :q OR email ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

          render json: UserSerializer.collection(paginate(scope.order(created_at: :desc)))
        end

        # GET /api/v1/admin/users/:id
        def show
          render json: UserSerializer.call(@user).merge(
            designs_count: @user.dress_designs.count,
            measurements_count: @user.measurements.count,
            orders_count: @user.orders.count
          )
        end

        # PATCH /api/v1/admin/users/:id — role changes, deactivation, ratings.
        def update
          if @user.update(user_params)
            render json: UserSerializer.call(@user)
          else
            render_errors(@user.error_messages)
          end
        end

        private

        def set_user
          @user = User.find(params[:id])
        end

        def user_params
          attrs = params.permit(:name, :phone, :bio, :city, :state, :rating,
                                :years_experience, :specialization).to_h.compact_blank

          attrs["role"] = params[:role] if User.roles.key?(params[:role].to_s)
          attrs["active"] = ActiveModel::Type::Boolean.new.cast(params[:active]) if params.key?(:active)
          attrs
        end
      end
    end
  end
end
