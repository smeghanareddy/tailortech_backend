class Boutique < ApplicationRecord
  include GeoLocatable

  belongs_to :owner, class_name: "User", optional: true

  has_one_attached :cover_image
  has_many_attached :gallery

  has_many :orders, dependent: :nullify

  validates :name, presence: true, length: { maximum: 160 }
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :active,   -> { where(active: true) }
  scope :in_city,  ->(city) { city.present? ? where("city ILIKE ?", city.to_s.strip) : all }
  scope :top_rated, -> { order(rating: :desc, reviews_count: :desc) }
  scope :search, lambda { |term|
    term.present? ? where("name ILIKE :q OR description ILIKE :q OR city ILIKE :q", q: "%#{term}%") : all
  }

  def full_address
    [address_line, city, state, pincode, country].compact_blank.join(", ")
  end

  def location
    [city, state].compact_blank.join(", ").presence
  end

  def cover_image_url
    AttachmentUrl.call(cover_image)
  end

  def maps_url
    return nil if latitude.blank? || longitude.blank?

    "https://www.google.com/maps/dir/?api=1&destination=#{latitude},#{longitude}"
  end
end
