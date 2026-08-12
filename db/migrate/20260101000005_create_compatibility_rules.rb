class CreateCompatibilityRules < ActiveRecord::Migration[7.1]
  def change
    create_table :compatibility_rules do |t|
      t.references :source_element, null: false,
                   foreign_key: { to_table: :design_elements }

      # Either a specific target element (allow/block) or a whole category
      # (block_category — e.g. "Halter Neck disables all sleeves").
      t.references :target_element,
                   foreign_key: { to_table: :design_elements }
      t.string  :target_category, null: false

      # allow | block | block_category
      t.string  :mode, null: false, default: "allow"
      t.text    :note

      t.timestamps
    end

    add_index :compatibility_rules, %i[source_element_id target_category mode],
              name: "index_compat_rules_on_source_target_mode"
    add_index :compatibility_rules, %i[source_element_id target_element_id mode],
              unique: true, name: "index_compat_rules_uniqueness"
  end
end
