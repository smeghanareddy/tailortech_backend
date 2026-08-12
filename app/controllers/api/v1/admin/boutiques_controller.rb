module Api
  module V1
    module Admin
      class BoutiquesController < BaseController
        before_action :set_boutique, only: %i[show update destroy]

        # GET /api/v1/admin/boutiques
        def index
          scope = Boutique.in_city(params[:city]).search(params[:q]).order(:name)
          render json: BoutiqueSerializer.collection(paginate(scope))
        end

        # GET /api/v1/admin/boutiques/:id
        def show
          render json: BoutiqueSerializer.call(@boutique)
        end

        # POST /api/v1/admin/boutiques
        def create
          boutique = Boutique.new(boutique_params)

          if boutique.save
            attach_images(boutique)
            render json: BoutiqueSerializer.call(boutique), status: :created
          else
            render_errors(boutique.error_messages)
          end
        end

        # PATCH /api/v1/admin/boutiques/:id
        def update
          if @boutique.update(boutique_params)
            attach_images(@boutique)
            render json: BoutiqueSerializer.call(@boutique)
          else
            render_errors(@boutique.error_messages)
          end
        end

        # DELETE /api/v1/admin/boutiques/:id
        def destroy
          @boutique.destroy!
          head :no_content
        end

        private

        def set_boutique
          @boutique = Boutique.find(params[:id])
        end

        def boutique_params
          attrs = params.permit(:owner_id, :name, :description, :phone, :email, :website,
                                :address_line, :city, :state, :country, :pincode,
                                :latitude, :longitude, :rating, :reviews_count,
                                services: [], opening_hours: {}).to_h.compact_blank

          attrs["active"] = ActiveModel::Type::Boolean.new.cast(params[:active]) if params.key?(:active)
          attrs
        end

        def attach_images(boutique)
          boutique.cover_image.attach(params[:cover_image]) if params[:cover_image].present?
          Array(params[:gallery]).compact_blank.each { |file| boutique.gallery.attach(file) }
        end
      end
    end
  end
end
