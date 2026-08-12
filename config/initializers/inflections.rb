# Intentionally no acronym inflections: Zeitwerk maps app/controllers/api/v1
# to Api::V1 and app/services/ai_client.rb to AiClient. Registering "API"/"AI"
# as acronyms would silently break both.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.uncountable %w[embroidery_intensity]
end
