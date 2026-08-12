class Order < ApplicationRecord
  enum :status, {
    placed: 0, confirmed: 1, in_tailoring: 2, ready: 3, delivered: 4, cancelled: 5
  }, default: :placed

  belongs_to :user
  belongs_to :dress_design
  belongs_to :measurement, optional: true
  belongs_to :boutique, optional: true
  belongs_to :designer, class_name: "User", optional: true

  validates :order_number, presence: true, uniqueness: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, inclusion: { in: %w[INR USD EUR GBP AED] }

  before_validation :assign_order_number, on: :create
  before_create :freeze_snapshots

  scope :recent, -> { order(created_at: :desc) }
  scope :open, -> { where.not(status: %i[delivered cancelled]) }

  def price
    (price_cents.to_i / 100.0).round(2)
  end

  def price=(amount)
    self.price_cents = (amount.to_f * 100).round
  end

  private

  def assign_order_number
    return if order_number.present?

    loop do
      candidate = "TT-#{Time.current.strftime('%Y%m')}-#{SecureRandom.alphanumeric(6).upcase}"
      next if Order.exists?(order_number: candidate)

      self.order_number = candidate
      break
    end
  end

  # An order must survive later edits to the design or the measurement profile.
  def freeze_snapshots
    self.design_snapshot = DressDesignSerializer.detail(dress_design) if dress_design && design_snapshot.blank?
    self.measurement_snapshot = MeasurementSerializer.call(measurement) if measurement && measurement_snapshot.blank?
  end
end
