require "rails_helper"

RSpec.describe "Measurements", type: :request do
  let(:user) { create(:user) }

  it "creates a measurement profile" do
    post "/api/v1/measurements",
         params: { name: "Wedding", height: 163, bust: 88, waist: 71, hip: 96 },
         headers: auth_headers(user)

    expect(response).to have_http_status(:created)
    expect(json["height"]).to eq(163.0)
    expect(json["ai_estimated"]).to be(false)
  end

  it "rejects values outside the accepted human range" do
    post "/api/v1/measurements",
         params: { name: "Nonsense", height: 900 },
         headers: auth_headers(user)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json["errors"].join).to match(/between 60 and 250/)
  end

  it "treats blank inputs as not-measured rather than zero" do
    post "/api/v1/measurements",
         params: { name: "Partial", height: 160, bust: "", waist: "" },
         headers: auth_headers(user)

    expect(response).to have_http_status(:created)
    expect(json["bust"]).to be_nil
  end

  it "reports service unavailable when the AI estimator is off" do
    file = Rack::Test::UploadedFile.new(StringIO.new("fake"), "image/jpeg", original_filename: "me.jpg")

    post "/api/v1/measurements/estimate_from_photo",
         params: { photo: file }, headers: auth_headers(user)

    expect(response).to have_http_status(:service_unavailable)
    expect(json["error"]).to be_present
  end
end
