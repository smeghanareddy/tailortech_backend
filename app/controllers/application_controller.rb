class ApplicationController < ActionController::API
  include ErrorHandling
  include Authentication

  def route_not_found
    render json: { error: "Not found: #{request.method} #{request.path}" }, status: :not_found
  end
end
