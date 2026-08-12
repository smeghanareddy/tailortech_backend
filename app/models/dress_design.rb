class DressDesign < ApplicationRecord
  SKETCH_STATUSES = %w[pending processing ready failed].freeze

  enum :status, { draft: 0, completed: 1, ordered: 2, archived: 3 }, default: :draft

  belongs_to :user
  belongs_to :designer, class_name: "User", optional: true
  belongs_to :source_design, class_name: "DressDesign", optional: true

  has_many :copies, class_name: "DressDesign", foreign_key: :source_design_id,
                    inverse_of: :source_design, dependent: :nullify
  has_many :virtual_tryons, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error

  # Temporary custom uploads from the studio. Per spec these belong to this
  # design only — they never enter the shared Design Library.
  has_one_attached :neck_image
  has_one_attached :sleeve_image
  has_one_attached :dress_image
  has_one_attached :fabric_image

  has_one_attached :sketch     # AI-generated sketch
  has_one_attached :preview    # flattened layer-composited preview

  validates :name, length: { maximum: 160 }, allow_blank: true
  validates :color, :bodice_color, :skirt_color,
            format: { with: /\A#(?:[0-9a-fA-F]{3}){1,2}\z/, message: "must be a hex colour" },
            allow_blank: true
  validates :sketch_status, inclusion: { in: SKETCH_STATUSES }

  before_validation :assign_default_name
  before_validation :backfill_colors
  before_save :refresh_preview_fingerprint

  scope :recent, -> { order(updated_at: :desc) }
  scope :portfolio, -> { where(public_portfolio: true) }
  scope :with_sketch, lambda {
    left_joins(:sketch_attachment)
      .where("active_storage_attachments.id IS NOT NULL OR dress_designs.sketch_url IS NOT NULL")
  }

  # ── Component tree helpers (mirror the frontend design store) ────

  def embroidery = components["embroidery"] || {}
  def lace       = components["lace"] || {}
  def buttons    = components["buttons"] || {}

  def bodice_colors = components.dig("colors", "bodice") || []
  def skirt_colors  = components.dig("colors", "skirt")  || []

  def neck_front_type = components.dig("neck", "front").presence || neck_type
  def neck_back_type_resolved = components.dig("neck", "back").presence || neck_back_type

  # ── Sketch ───────────────────────────────────────────────────────

  def sketch_display_url
    AttachmentUrl.call(sketch) || sketch_url
  end

  def preview_display_url
    AttachmentUrl.call(preview)
  end

  def custom_image_urls
    {
      neck:   AttachmentUrl.call(neck_image),
      sleeve: AttachmentUrl.call(sleeve_image),
      dress:  AttachmentUrl.call(dress_image),
      fabric: AttachmentUrl.call(fabric_image)
    }.compact
  end

  # Stable key for the Redis-backed layer cache. Changing any visual attribute
  # changes the fingerprint, so only genuinely new combinations get rendered.
  def compute_preview_fingerprint
    payload = {
      neck: neck_type, neck_back: neck_back_type, sleeve: sleeve_type,
      dress: dress_type, fabric: fabric, pattern: pattern,
      color: color, bodice: bodice_color, skirt: skirt_color,
      components: components,
      custom: custom_image_urls.keys.sort
    }
    Digest::SHA256.hexdigest(payload.to_json)
  end

  def editable_by?(actor)
    return false if actor.blank?

    actor.super_admin? || user_id == actor.id || designer_id == actor.id
  end

  private

  def assign_default_name
    return if name.present?

    self.name = [dress_type, "design"].compact_blank.join(" ").titleize.presence || "Untitled Design"
  end

  # The studio posts a single `color`; keep the zone colours consistent so the
  # compositor always has something to work with.
  def backfill_colors
    self.bodice_color = color if bodice_color.blank?
    self.skirt_color  = bodice_color if skirt_color.blank?
    self.color        = bodice_color if color.blank?
  end

  def refresh_preview_fingerprint
    self.preview_fingerprint = compute_preview_fingerprint
  end
end
