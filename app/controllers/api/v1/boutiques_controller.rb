module Api
  module V1
    # "Nearest Boutique" — search, distance, ratings, contact, navigation.
    class BoutiquesController < BaseController
      skip_before_action :authenticate_user!

      # GET /api/v1/boutiques?lat=13.08&lng=80.27&radius=25
      # GET /api/v1/boutiques?city=Chennai&q=bridal
      def index
        scope = Boutique.active.in_city(params[:city]).search(params[:q])

        scope = if params[:lat].present? && params[:lng].present?
                  scope.near(params[:lat], params[:lng], params[:radius].presence || 25)
                else
                  scope.top_rated
                end

        render json: BoutiqueSerializer.collection(paginate(scope))
      end

      # GET /api/v1/boutiques/:id
      def show
        boutique = Boutique.active.find(params[:id])
        render json: BoutiqueSerializer.call(boutique)
      end
    end
  end
end
