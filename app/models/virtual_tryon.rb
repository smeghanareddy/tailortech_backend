class VirtualTryon < ApplicationRecord
  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }, default: :pending

  belongs_to :user
  # Optional: a try-on can be against a garment image linked from another
  # site rather than one of the customer's saved designs.
  belongs_to :dress_design, optional: true
  belongs_to :measurement, optional: true

  has_one_attached :source_photo
  has_one_attached :result_photo
  # The linked image, copied into our own storage so the preview does not
  # break when the other site changes or removes it.
  has_one_attached :garment_image

  # `validates :source_photo, presence: true` does not work on an
  # ActiveStorage::Attached::One — it is never blank. Check `attached?`.
  validate :source_photo_required, on: :create
  validate :garment_required, on: :create

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: :completed) }

  def source_photo_display_url
    AttachmentUrl.call(source_photo)
  end

  def result_photo_display_url
    AttachmentUrl.call(result_photo) || result_photo_url
  end

  def mark_processing!
    update!(status: :processing, error_message: nil)
  end

  def mark_failed!(message)
    update!(status: :failed, error_message: message.to_s.truncate(500))
  end

  def garment_image_display_url
    AttachmentUrl.call(garment_image)
  end

  # What the try-on should actually place on the photo.
  def garment_url
    garment_image_display_url || dress_design&.sketch_display_url ||
      dress_design&.preview_display_url
  end

  def external_garment?
    garment_source_url.present?
  end

  private

  def source_photo_required
    errors.add(:source_photo, "is required") unless source_photo.attached?
  end

  def garment_required
    return if dress_design_id.present? || garment_source_url.present?

    errors.add(:base, "Choose a saved design or paste an image link to try on")
  end
end
