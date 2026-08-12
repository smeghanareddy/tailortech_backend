# Estimates body measurements from an uploaded front-view photo.
#
# The response is deliberately *not* persisted: the frontend pre-fills the form
# and the user reviews and adjusts before saving, which is what the spec calls
# for ("Estimate → Preview → Manual adjustment → Save").
class MeasurementEstimator
  class EstimationError < StandardError; end

  def self.call(...) = new(...).call

  def initialize(photo:, height_hint: nil, client: AiClient.new)
    @photo = photo
    @height_hint = height_hint
    @client = client
  end

  def call
    raise EstimationError, "No photo supplied" if photo.blank?

    response = client.estimate_measurements(
      photo_io: photo.tempfile,
      filename: photo.original_filename,
      content_type: photo.content_type,
      height_hint: height_hint
    )

    {
      estimated: normalize(response[:measurements] || response["measurements"] || response),
      confidence: response[:confidence] || response["confidence"],
      ai_estimated: true
    }
  rescue AiClient::Unavailable => e
    raise EstimationError, "AI measurement service unavailable — enter measurements manually (#{e.message})"
  rescue AiClient::Error => e
    raise EstimationError, e.message
  end

  private

  attr_reader :photo, :height_hint, :client

  # Keep only the fields the form knows about, rounded to one decimal, and drop
  # anything outside the accepted human range rather than pre-filling nonsense.
  def normalize(values)
    values = values.to_h.with_indifferent_access
    Measurement::FIELDS.index_with do |field|
      raw = values[field]
      next nil if raw.blank?

      rounded = raw.to_f.round(1)
      Measurement::RANGES[field].cover?(rounded) ? rounded : nil
    end.compact
  end
end
