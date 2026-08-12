class DesignerCustomer < ApplicationRecord
  belongs_to :designer, class_name: "User"
  belongs_to :customer, class_name: "User"

  validates :designer_id, uniqueness: { scope: :customer_id,
                                        message: "already has this customer" }
  validate  :designer_must_be_a_designer
  validate  :cannot_link_to_self

  scope :recent, -> { order(Arel.sql("COALESCE(last_activity_at, created_at) DESC")) }

  def touch_activity!
    update_column(:last_activity_at, Time.current)
  end

  private

  def designer_must_be_a_designer
    return if designer.blank? || designer.designer_or_admin?

    errors.add(:designer, "must be a designer account")
  end

  def cannot_link_to_self
    return if designer_id.blank? || designer_id != customer_id

    errors.add(:customer, "cannot be the designer themselves")
  end
end
