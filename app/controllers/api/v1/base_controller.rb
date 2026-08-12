module Api
  module V1
    class BaseController < ApplicationController
      MAX_PER_PAGE = 100

      private

      # Opt-in pagination — collections stay plain JSON arrays (which is what
      # the frontend maps over) and the page metadata rides in headers.
      def paginate(scope)
        page = params[:page].to_i.positive? ? params[:page].to_i : 1
        per_page = params[:per_page].to_i.positive? ? params[:per_page].to_i : 50
        per_page = per_page.clamp(1, MAX_PER_PAGE)

        records = scope.page(page).per(per_page)

        response.set_header("X-Total-Count", records.total_count.to_s)
        response.set_header("X-Page", page.to_s)
        response.set_header("X-Per-Page", per_page.to_s)

        records
      end

      def boolean_param(key, default: false)
        return default unless params.key?(key)

        ActiveModel::Type::Boolean.new.cast(params[key]) || false
      end
    end
  end
end
