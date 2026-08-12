class User < ApplicationRecord
  include GeoLocatable

  has_secure_password

  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  enum :role, { customer: 0, designer: 1, super_admin: 2 }, default: :customer

  has_one_attached :avatar

  has_many :dress_designs, dependent: :destroy
  has_many :authored_designs, class_name: "DressDesign", foreign_key: :designer_id,
                              inverse_of: :designer, dependent: :nullify
  has_many :measurements, dependent: :destroy
  has_many :virtual_tryons, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :boutiques, foreign_key: :owner_id, inverse_of: :owner, dependent: :nullify

  # Designer ↔ customer book
  has_many :designer_customers, foreign_key: :designer_id,
                                inverse_of: :designer, dependent: :destroy
  has_many :customers, through: :designer_customers, source: :customer

  has_many :customer_designers, class_name: "DesignerCustomer", foreign_key: :customer_id,
                                inverse_of: :customer, dependent: :destroy
  has_many :designers, through: :customer_designers, source: :designer

  validates :name,  presence: true, length: { maximum: 120 }
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: EMAIL_FORMAT, message: "is invalid" }
  validates :password, length: { minimum: 6 }, allow_nil: true
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }

  normalizes :email, with: ->(value) { value.to_s.strip.downcase }

  # NB: `designer` (singular) already exists as an enum scope; this is the
  # readable alias used by the boutique directory.
  scope :active,            -> { where(active: true) }
  scope :designer_accounts, -> { where(role: :designer) }
  scope :in_city,           ->(city) { city.present? ? where("city ILIKE ?", city.to_s.strip) : all }
  scope :top_rated,         -> { order(rating: :desc, reviews_count: :desc, created_at: :desc) }

  def staff?
    super_admin?
  end

  def designer_or_admin?
    designer? || super_admin?
  end

  def location
    [city, state].compact_blank.join(", ").presence
  end

  # Designs this user owns *or* authored for a customer — a designer's
  # portfolio is mostly the latter.
  def portfolio_scope
    DressDesign.where(user_id: id).or(DressDesign.where(designer_id: id))
  end

  # Best portfolio piece for the boutique card.
  def best_design
    finished = portfolio_scope.where(status: :completed)
    finished.with_sketch.order(updated_at: :desc).first ||
      finished.order(updated_at: :desc).first
  end

  def touch_login!
    update_column(:last_login_at, Time.current)
  end
end
