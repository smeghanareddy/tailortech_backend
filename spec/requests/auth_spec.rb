require "rails_helper"

RSpec.describe "Auth", type: :request do
  describe "POST /api/v1/auth/register" do
    it "returns a token and the user" do
      post "/api/v1/auth/register", params: {
        name: "Divya", email: "divya@example.com",
        password: "password123", password_confirmation: "password123", role: "customer"
      }

      expect(response).to have_http_status(:created)
      expect(json["token"]).to be_present
      expect(json.dig("user", "email")).to eq("divya@example.com")
    end

    it "never grants super admin through self-service registration" do
      post "/api/v1/auth/register", params: {
        name: "Sneaky", email: "sneaky@example.com",
        password: "password123", role: "super_admin"
      }

      expect(json.dig("user", "role")).to eq("customer")
    end

    it "returns errors as an array of strings" do
      post "/api/v1/auth/register", params: { name: "", email: "bad", password: "x" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to be_an(Array)
      expect(json["error"]).to eq(json["errors"].first)
    end
  end

  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, email: "me@example.com", password: "password123") }

    it "signs in with valid credentials" do
      post "/api/v1/auth/login", params: { email: "me@example.com", password: "password123" }

      expect(response).to have_http_status(:ok)
      expect(json["token"]).to be_present
    end

    it "rejects a wrong password with 401" do
      post "/api/v1/auth/login", params: { email: "me@example.com", password: "nope" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/auth/me" do
    let(:user) { create(:user) }

    it "requires a token" do
      get "/api/v1/auth/me"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the current user" do
      get "/api/v1/auth/me", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json.dig("user", "id")).to eq(user.id)
    end
  end
end
