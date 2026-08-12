# "High Neck allows only Full and Three Quarter sleeves."
# "Halter Neck disables sleeves entirely."
# "High Neck front does not allow a Deep U back."
#
# Resolution semantics (see CompatibilityChecker):
#   block_category → nothing in that category is selectable
#   allow          → if ANY allow rule exists for (source, category), only
#                    those targets are selectable
#   block          → otherwise everything except the blocked targets
class CompatibilityRule < ApplicationRecord
  MODES = %w[allow block block_category].freeze

  belongs_to :source_element, class_name: "DesignElement"
  belongs_to :target_element, class_name: "DesignElement", optional: true

  validates :mode, inclusion: { in: MODES }
  validates :target_category, presence: true,
                              inclusion: { in: DesignElement::CATEGORIES }
  validate  :target_element_required_unless_category_block
  validate  :target_element_matches_category

  scope :for_source,   ->(element_id) { where(source_element_id: element_id) }
  scope :for_category, ->(category) { where(target_category: category.to_s) }
  scope :allowing,     -> { where(mode: "allow") }
  scope :blocking,     -> { where(mode: "block") }
  scope :category_blocks, -> { where(mode: "block_category") }

  private

  def target_element_required_unless_category_block
    return if mode == "block_category" || target_element_id.present?

    errors.add(:target_element, "is required for #{mode} rules")
  end

  def target_element_matches_category
    return if target_element.blank? || target_element.category == target_category

    errors.add(:target_element, "does not belong to category #{target_category}")
  end
end
