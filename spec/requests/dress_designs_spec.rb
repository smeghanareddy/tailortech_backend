require "rails_helper"

RSpec.describe "Dress designs", type: :request do
  let(:user) { create(:user) }

  describe "GET /api/v1/dress_designs" do
    it "returns a bare array of the caller's designs" do
      create(:dress_design, user: user, name: "Mine")
      create(:dress_design, name: "Someone else's")

      get "/api/v1/dress_designs", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json).to be_an(Array)
      expect(json.map { |d| d["name"] }).to eq(["Mine"])
    end
  end

  describe "POST /api/v1/dress_designs" do
    it "accepts the flat multipart payload the studio sends" do
      post "/api/v1/dress_designs",
           params: { name: "Teal Anarkali", neck_type: "V-Neck", sleeve_type: "Full Sleeve",
                     dress_type: "Anarkali", color: "#0d9488", fabric: "Silk",
                     status: "completed" },
           headers: auth_headers(user)

      expect(response).to have_http_status(:created)
      expect(json["id"]).to be_present
      expect(json["status"]).to eq("completed")
      # A single posted colour fills both zones so the compositor has values.
      expect(json["bodice_color"]).to eq("#0d9488")
    end

    it "rejects a malformed colour" do
      post "/api/v1/dress_designs",
           params: { name: "Bad", color: "teal" },
           headers: auth_headers(user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"].join).to match(/hex colour/i)
    end
  end

  describe "DELETE /api/v1/dress_designs/:id" do
    it "refuses to delete someone else's design" do
      other = create(:dress_design)

      delete "/api/v1/dress_designs/#{other.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/dress_designs/:id/preview" do
    it "returns an ordered layer manifest" do
      design = create(:dress_design, user: user)

      get "/api/v1/dress_designs/#{design.id}/preview", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json["layers"]).to be_an(Array)
      expect(json["layers"].map { |l| l["z_index"] }).to eq(json["layers"].map { |l| l["z_index"] }.sort)
    end
  end
end
