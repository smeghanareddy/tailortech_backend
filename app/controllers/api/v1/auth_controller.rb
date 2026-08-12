module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_user!, only: %i[register login]

      # POST /api/v1/auth/register
      def register
        user = User.new(register_params)
        user.role = requested_role

        if user.save
          render json: { token: JsonWebToken.for_user(user), user: UserSerializer.call(user) },
                 status: :created
        else
          render_errors(user.error_messages)
        end
      end

      # POST /api/v1/auth/login
      def login
        user = User.find_by(email: params[:email].to_s.strip.downcase)

        unless user&.authenticate(params[:password].to_s)
          return render_errors("Invalid email or password", status: :unauthorized)
        end

        return render_errors("This account has been deactivated", status: :forbidden) unless user.active?

        user.touch_login!
        render json: { token: JsonWebToken.for_user(user), user: UserSerializer.call(user) }
      end

      # GET /api/v1/auth/me
      def me
        render json: { user: UserSerializer.call(current_user) }
      end

      # PATCH /api/v1/auth/profile
      def update_profile
        if current_user.update(profile_params)
          render json: { user: UserSerializer.call(current_user) }
        else
          render_errors(current_user.error_messages)
        end
      end

      # DELETE /api/v1/auth/logout
      #
      # Tokens are stateless; the client drops it. Kept so the frontend has a
      # single place to hook session teardown later.
      def logout
        head :no_content
      end

      private

      def register_params
        params.permit(:name, :email, :password, :password_confirmation, :phone, :city, :state)
      end

      def profile_params
        params.permit(:name, :phone, :bio, :city, :state, :address_line, :pincode,
                      :specialization, :years_experience, :avatar,
                      :latitude, :longitude)
      end

      # Self-service registration can never mint a super admin.
      def requested_role
        role = params[:role].to_s
        User.roles.key?(role) && role != "super_admin" ? role : "customer"
      end
    end
  end
end
