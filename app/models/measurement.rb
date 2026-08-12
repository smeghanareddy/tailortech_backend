class Measurement < ApplicationRecord
  # Sane human ranges in centimetres — the spec asks for validation on
  # acceptable measurement ranges.
  RANGES = {
    height:         (60..250),
    bust:           (40..200),
    waist:          (30..200),
    hip:            (40..220),
    shoulder_width: (20..80),
    neck_size:      (15..70),
    sleeve_length:  (5..100),
    dress_length:   (20..200)
  }.freeze

  FIELDS = RANGES.keys.freeze
  SOURCES = %w[manual ai_photo designer].freeze

  belongs_to :user
  belongs_to :created_by, class_name: "User", optional: true

  has_one_attached :reference_photo

  validates :name, presence: true, length: { maximum: 120 }
  validates :unit, inclusion: { in: %w[cm in] }
  validates :source, inclusion: { in: SOURCES }

  RANGES.each do |field, range|
    validates field,
              numericality: {
                greater_than_or_equal_to: range.min,
                less_than_or_equal_to: range.max,
                message: "must be between #{range.min} and #{range.max} cm"
              },
              allow_nil: true
  end

  validate :at_least_one_value

  scope :recent, -> { order(created_at: :desc) }

  def values
    FIELDS.index_with { |field| public_send(field) }
  end

  private

  def at_least_one_value
    return if FIELDS.any? { |field| public_send(field).present? }

    errors.add(:base, "Enter at least one measurement")
  end
end
