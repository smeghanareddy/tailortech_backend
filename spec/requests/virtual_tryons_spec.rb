require "rails_helper"

RSpec.describe "Virtual try-on from a link", type: :request do
  let(:user) { create(:user) }
  let(:photo) do
    Rack::Test::UploadedFile.new(StringIO.new("fake"), "image/png", original_filename: "me.png")
  end

  describe "RemoteImageFetcher SSRF guards" do
    it "refuses a non-http scheme" do
      expect { RemoteImageFetcher.call("file:///etc/passwd") }
        .to raise_error(RemoteImageFetcher::FetchError, /http and https/)
    end

    it "refuses loopback" do
      expect { RemoteImageFetcher.call("http://127.0.0.1:5432/x.png") }
        .to raise_error(RemoteImageFetcher::FetchError, /private address/)
    end

    it "refuses the cloud metadata endpoint" do
      expect { RemoteImageFetcher.call("http://169.254.169.254/latest/meta-data/") }
        .to raise_error(RemoteImageFetcher::FetchError, /private address/)
    end

    it "refuses private ranges" do
      %w[http://10.0.0.5/a.png http://192.168.1.10/a.png http://172.16.0.9/a.png].each do |url|
        expect { RemoteImageFetcher.call(url) }
          .to raise_error(RemoteImageFetcher::FetchError, /private address/)
      end
    end

    it "refuses a hostname that resolves to loopback" do
      allow(Resolv).to receive(:getaddresses).with("evil.test").and_return(["127.0.0.1"])

      expect { RemoteImageFetcher.call("http://evil.test/a.png") }
        .to raise_error(RemoteImageFetcher::FetchError, /private address/)
    end

    it "refuses a blank link" do
      expect { RemoteImageFetcher.call(" ") }
        .to raise_error(RemoteImageFetcher::FetchError, /Enter an image link/)
    end
  end

  describe "POST /api/v1/virtual_tryons" do
    it "rejects a link pointing at an internal address, with a clear message" do
      post "/api/v1/virtual_tryons",
           params: { garment_url: "http://localhost/secret.png", photo: photo },
           headers: auth_headers(user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["error"]).to match(/private address/)
      expect(VirtualTryon.count).to eq(0)
    end

    it "requires either a design or a link" do
      post "/api/v1/virtual_tryons",
           params: { photo: photo },
           headers: auth_headers(user)

      expect(response).to have_http_status(:not_found).or have_http_status(:unprocessable_entity)
    end

    it "requires a photo" do
      post "/api/v1/virtual_tryons",
           params: { garment_url: "https://example.com/a.png" },
           headers: auth_headers(user)

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "the model" do
    it "accepts a linked garment with no design" do
      tryon = user.virtual_tryons.new(garment_source_url: "https://example.com/a.png")
      tryon.source_photo.attach(io: StringIO.new("x"), filename: "p.png", content_type: "image/png")

      expect(tryon).to be_valid
    end

    it "rejects a try-on with neither a design nor a link" do
      tryon = user.virtual_tryons.new
      tryon.source_photo.attach(io: StringIO.new("x"), filename: "p.png", content_type: "image/png")

      expect(tryon).not_to be_valid
      expect(tryon.error_messages.join).to match(/saved design or paste an image link/)
    end
  end
end
