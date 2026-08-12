require "rails_helper"

RSpec.describe "Design elements", type: :request do
  describe "GET /api/v1/design_elements" do
    it "filters by category and returns a bare array" do
      create(:design_element, category: "neck", name: "V-Neck")
      create(:design_element, category: "sleeve", name: "Full Sleeve")

      get "/api/v1/design_elements", params: { category: "neck" }

      expect(response).to have_http_status(:ok)
      expect(json.map { |e| e["name"] }).to eq(["V-Neck"])
      expect(json.first).to include("id", "name", "image_url")
    end

    it "hides unpublished elements" do
      create(:design_element, category: "neck", name: "Draft", published: false)

      get "/api/v1/design_elements", params: { category: "neck" }

      expect(json).to be_empty
    end
  end

  describe "GET /api/v1/design_elements/:id/compatible" do
    it "disables a whole category when a block_category rule applies" do
      halter = create(:design_element, category: "neck", name: "Halter Neck")
      create(:design_element, category: "sleeve", name: "Full Sleeve")
      CompatibilityRule.create!(source_element: halter, target_category: "sleeve",
                                mode: "block_category", note: "Shoulders are bare")

      get "/api/v1/design_elements/#{halter.id}/compatible", params: { category: "sleeve" }

      expect(json["disabled"]).to be(true)
      expect(json["allowed"]).to be_empty
      expect(json["reason"]).to eq("Shoulders are bare")
    end

    it "narrows to the allow-list when allow rules exist" do
      high = create(:design_element, category: "neck", name: "High Neck")
      full = create(:design_element, category: "sleeve", name: "Full Sleeve")
      create(:design_element, category: "sleeve", name: "Sleeveless")
      CompatibilityRule.create!(source_element: high, target_element: full,
                                target_category: "sleeve", mode: "allow")

      get "/api/v1/design_elements/#{high.id}/compatible", params: { category: "sleeve" }

      expect(json["disabled"]).to be(false)
      expect(json["allowed"].map { |e| e["name"] }).to eq(["Full Sleeve"])
    end
  end
end
