module Api
  module V1
    module Admin
      class CompatibilityRulesController < BaseController
        before_action :set_rule, only: %i[update destroy]

        # GET /api/v1/admin/compatibility_rules?source_element_id=12
        def index
          scope = CompatibilityRule.includes(:source_element, :target_element)
          scope = scope.for_source(params[:source_element_id]) if params[:source_element_id].present?
          scope = scope.for_category(params[:target_category]) if params[:target_category].present?

          render json: scope.map { |rule| serialize(rule) }
        end

        # POST /api/v1/admin/compatibility_rules
        #   { source_element_id, target_category, mode, target_element_id, note }
        #
        # Bulk form: pass `target_element_ids: []` to create one rule per target.
        def create
          rules = build_rules

          invalid = rules.reject(&:valid?)
          return render_errors(invalid.flat_map(&:error_messages).uniq) if invalid.any?

          rules.each(&:save!)
          render json: rules.map { |rule| serialize(rule) }, status: :created
        end

        # PATCH /api/v1/admin/compatibility_rules/:id
        def update
          if @rule.update(rule_params)
            render json: serialize(@rule)
          else
            render_errors(@rule.error_messages)
          end
        end

        # DELETE /api/v1/admin/compatibility_rules/:id
        def destroy
          @rule.destroy!
          head :no_content
        end

        private

        def set_rule
          @rule = CompatibilityRule.find(params[:id])
        end

        def rule_params
          params.permit(:source_element_id, :target_element_id, :target_category, :mode, :note)
        end

        def build_rules
          target_ids = Array(params[:target_element_ids]).compact_blank
          return [CompatibilityRule.new(rule_params)] if target_ids.empty?

          target_ids.map do |target_id|
            CompatibilityRule.new(rule_params.except(:target_element_id)
                                             .merge(target_element_id: target_id))
          end
        end

        def serialize(rule)
          {
            id: rule.id,
            mode: rule.mode,
            note: rule.note,
            target_category: rule.target_category,
            source_element: DesignElementSerializer.call(rule.source_element),
            target_element: DesignElementSerializer.call(rule.target_element),
            created_at: rule.created_at
          }
        end
      end
    end
  end
end
