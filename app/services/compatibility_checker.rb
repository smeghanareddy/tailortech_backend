# Resolves the database-driven compatibility rules into "what can I still pick?"
#
#   Halter Neck   → sleeves disabled entirely      (block_category)
#   High Neck     → only Full / Three Quarter      (allow)
#   High Neck     → back neck cannot be Deep U/V   (block)
#
# Given one or more current selections, `for_category` returns the subset of a
# category that is still selectable, and `allowed?` answers a single pair.
class CompatibilityChecker
  def self.for_category(...) = new(...).for_category
  def self.summary(...)      = new(...).summary

  # `selections` maps category => element name, e.g.
  #   { "neck" => "Halter Neck", "dress_type" => "A-Line" }
  def initialize(selections:, target_category: nil)
    @selections = selections.to_h.compact_blank.transform_keys(&:to_s)
    @target_category = target_category.to_s.presence
  end

  # => { allowed: [DesignElement], blocked: [DesignElement], disabled: bool }
  def for_category(category = target_category)
    category = category.to_s
    candidates = DesignElement.published.in_category(category).ordered.to_a
    rules = rules_for(category)

    if rules.any? { |r| r.mode == "block_category" }
      return { category: category, disabled: true, allowed: [], blocked: candidates,
               reason: category_block_reason(rules) }
    end

    allow_ids = rules.select { |r| r.mode == "allow" }.map(&:target_element_id).compact
    block_ids = rules.select { |r| r.mode == "block" }.map(&:target_element_id).compact

    allowed =
      if allow_ids.any?
        candidates.select { |el| allow_ids.include?(el.id) }
      else
        candidates.reject { |el| block_ids.include?(el.id) }
      end

    { category: category, disabled: false, allowed: allowed,
      blocked: candidates - allowed, reason: nil }
  end

  # Every dependent category at once — what the studio needs after each click.
  def summary(categories = DesignElement::CATEGORIES)
    Array(categories).index_with { |category| for_category(category) }
  end

  def allowed?(category, name)
    result = for_category(category)
    return false if result[:disabled]

    result[:allowed].any? { |el| el.name.casecmp?(name.to_s) }
  end

  private

  attr_reader :selections, :target_category

  def source_element_ids
    @source_element_ids ||= selections.filter_map do |category, name|
      DesignElement.published.in_category(category)
                   .where("LOWER(name) = ? OR slug = ?", name.to_s.downcase, name.to_s.parameterize)
                   .pick(:id)
    end
  end

  def rules_for(category)
    return [] if source_element_ids.empty?

    @rules ||= CompatibilityRule.where(source_element_id: source_element_ids)
                                .includes(:target_element).to_a
    @rules.select { |r| r.target_category == category }
  end

  def category_block_reason(rules)
    rule = rules.find { |r| r.mode == "block_category" }
    rule&.note.presence || "Not available with the current selection"
  end
end
