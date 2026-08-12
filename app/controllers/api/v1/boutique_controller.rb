module Api
  module V1
    # The "Designer Boutique" directory — designers, not shopfronts.
    # See BoutiquesController for the physical store locator.
    class BoutiqueController < BaseController
      skip_before_action :authenticate_user!

      # GET /api/v1/boutique?city=Chennai
      def index
        designers = User.active.designer_accounts
                        .in_city(params[:city])
                        .includes(avatar_attachment: :blob)

        designers = if params[:lat].present? && params[:lng].present?
                      designers.near(params[:lat], params[:lng], params[:radius].presence || 50)
                    else
                      designers.top_rated
                    end

        render json: DesignerDirectorySerializer.collection(designers.limit(60))
      end

      # GET /api/v1/boutique/:id
      def show
        designer = User.active.designer_accounts.find(params[:id])
        render json: DesignerDirectorySerializer.detail(designer)
      end
    end
  end
end
