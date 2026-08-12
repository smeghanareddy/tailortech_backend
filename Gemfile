source "https://rubygems.org"

ruby ">= 3.2.0"

# ── Core ─────────────────────────────────────────────────────────
gem "rails", "~> 7.1.3"
gem "pg", "~> 1.5"
gem "puma", ">= 6.4"
gem "bootsnap", require: false

# ── Auth ─────────────────────────────────────────────────────────
gem "bcrypt", "~> 3.1", ">= 3.1.20"
gem "jwt", "~> 2.8"

# ── API plumbing ─────────────────────────────────────────────────
gem "rack-cors"
gem "kaminari", "~> 1.2"

# ── Background work / cache ──────────────────────────────────────
gem "redis", "~> 5.0"
gem "sidekiq", "~> 7.2"

# ── Storage (design assets, sketches, try-on photos) ─────────────
gem "aws-sdk-s3", "~> 1.143", require: false
gem "image_processing", "~> 1.12"

# ── Python AI service client ─────────────────────────────────────
gem "faraday", "~> 2.9"
gem "faraday-multipart", "~> 1.0"

gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "dotenv-rails"
  gem "debug", platforms: %i[mri windows]
  gem "rspec-rails", "~> 6.1"
  gem "factory_bot_rails"
end

group :development do
  gem "listen", "~> 3.8"
end
