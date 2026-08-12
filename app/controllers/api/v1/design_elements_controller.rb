module Api
  module V1
    class DesignElementsController < BaseController
      # The Design Studio loads the library before the user signs in on some
      # flows, and the option grid is not sensitive.
      skip_before_action :authenticate_user!, only: %i[index show categories compatible]

      # GET /api/v1/design_elements?category=neck
      #
      # Returns a plain array — Step1Neck/Step2Sleeve/Step3DressType/
      # Step4ColorFabric all do `setOptions(data)` directly.
      def index
        elements = DesignElement.published
                                .then { |scope| params[:category].present? ? scope.in_category(params[:category]) : scope }
                                .search(params[:q])
                                .ordered

        elements = elements.ready if boolean_param(:ready_only)

        render json: DesignElementSerializer.collection(elements)
      end

      # GET /api/v1/design_elements/:id
      def show
        element = DesignElement.published.find(params[:id])
        render json: DesignElementSerializer.detail(element)
      end

      # GET /api/v1/design_elements/categories
      def categories
        counts = DesignElement.published.group(:category).count
        render json: DesignElement::CATEGORIES.map { |category|
          { category: category, label: category.humanize, count: counts.fetch(category, 0) }
        }
      end

      # GET /api/v1/design_elements/:id/compatible?category=sleeve
      #
      # "If Neckline = Halter → automatically disable sleeves."
      def compatible
        element = DesignElement.published.find(params[:id])
        target = params[:category].presence

        checker = CompatibilityChecker.new(
          selections: { element.category => element.name },
          target_category: target
        )

        if target.present?
          render json: serialize_compatibility(checker.for_category(target))
        else
          render json: checker.summary(dependent_categories(element.category))
                              .transform_values { |result| serialize_compatibility(result) }
        end
      end

      private

      def serialize_compatibility(result)
        {
          category: result[:category],
          disabled: result[:disabled],
          reason: result[:reason],
          allowed: DesignElementSerializer.collection(result[:allowed]),
          blocked_ids: result[:blocked].map(&:id)
        }
      end

      # Categories whose options can be constrained by the given one.
      def dependent_categories(category)
        case category
        when "neck"       then %w[back_neck sleeve dress_type]
        when "dress_type" then %w[sleeve neck skirt hemline]
        when "sleeve"     then %w[neck lace]
        when "fabric"     then %w[pattern embroidery lace]
        else DesignElement::CATEGORIES - [category]
        end
      end
    end
  end
end
