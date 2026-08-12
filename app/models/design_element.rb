# One interchangeable garment component: a neckline, a sleeve, a dress
# silhouette, a fabric, an embroidery motif, a lace, a belt, a button…
#
# Every element carries up to three transparent layers (front / back / shadow)
# so the rendering engine can compose a dress without ever storing a
# pre-rendered combination.
class DesignElement < ApplicationRecord
  CATEGORIES = %w[
    neck back_neck sleeve dress_type bodice skirt hemline
    fabric pattern color embroidery lace belt button accessory
  ].freeze

  # Default paint order for the compositor (Body → … → Shadow).
  DEFAULT_Z_INDEX = {
    "dress_type"  => 20,
    "bodice"      => 25,
    "skirt"       => 26,
    "hemline"     => 27,
    "neck"        => 30,
    "back_neck"   => 30,
    "sleeve"      => 40,
    "fabric"      => 50,
    "pattern"     => 55,
    "embroidery"  => 60,
    "lace"        => 70,
    "belt"        => 75,
    "button"      => 80,
    "accessory"   => 85,
    "color"       => 10
  }.freeze

  PROCESSING_STATUSES = %w[pending processing ready failed].freeze

  belongs_to :created_by, class_name: "User", optional: true

  has_one_attached :front_image
  has_one_attached :back_image
  has_one_attached :shadow_image
  has_one_attached :thumbnail
  # The untouched upload, kept so an asset can be re-processed later.
  has_one_attached :source_image

  has_many :compatibility_rules, foreign_key: :source_element_id,
                                 inverse_of: :source_element, dependent: :destroy
  has_many :inbound_compatibility_rules, class_name: "CompatibilityRule",
                                         foreign_key: :target_element_id,
                                         inverse_of: :target_element, dependent: :destroy

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :name, presence: true, length: { maximum: 120 }
  validates :slug, presence: true, uniqueness: { scope: :category }
  validates :processing_status, inclusion: { in: PROCESSING_STATUSES }
  validates :opacity, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  before_validation :assign_slug
  before_validation :assign_default_z_index

  scope :published,    -> { where(published: true) }
  scope :in_category,  ->(category) { where(category: category.to_s) }
  scope :ordered,      -> { order(:sort_order, :name) }
  scope :ready,        -> { where(processing_status: "ready") }
  scope :search,       lambda { |term|
    term.present? ? where("name ILIKE :q OR description ILIKE :q", q: "%#{term}%") : all
  }

  # Frontend contract: `image_url` is what the Design Studio renders in the
  # option grid. Prefer the processed transparent front layer, fall back to the
  # externally hosted URL stored on the record.
  def display_image_url
    AttachmentUrl.call(thumbnail) || AttachmentUrl.call(front_image) || image_url
  end

  def front_layer_url
    AttachmentUrl.call(front_image) || image_url
  end

  def back_layer_url
    AttachmentUrl.call(back_image)
  end

  def shadow_layer_url
    AttachmentUrl.call(shadow_image)
  end

  def ready?
    processing_status == "ready"
  end

  def mark_processing!
    update!(processing_status: "processing", processing_error: nil)
  end

  def mark_ready!
    update!(processing_status: "ready", processing_error: nil)
  end

  def mark_failed!(message)
    update!(processing_status: "failed", processing_error: message.to_s.truncate(500))
  end

  private

  def assign_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end

  def assign_default_z_index
    return unless z_index.to_i.zero?

    self.z_index = DEFAULT_Z_INDEX.fetch(category.to_s, 0)
  end
end
