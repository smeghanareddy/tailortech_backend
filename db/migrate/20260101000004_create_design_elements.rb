class CreateDesignElements < ActiveRecord::Migration[7.1]
  def change
    create_table :design_elements do |t|
      # neck / sleeve / dress_type / fabric / embroidery / lace / belt /
      # button / pattern / color
      t.string  :category, null: false
      t.string  :name,     null: false
      t.string  :slug,     null: false
      t.text    :description

      # Optional external URL — used when an asset is served straight from the
      # CDN instead of Active Storage.
      t.string  :image_url

      # Rendering metadata for the layer engine
      t.integer :z_index,     null: false, default: 0
      t.integer :sort_order,  null: false, default: 0
      t.string  :color_zone            # bodice / skirt / sleeve / lace / belt ...
      t.boolean :supports_color, null: false, default: true
      t.decimal :opacity, precision: 4, scale: 3, default: 1.0, null: false

      # Free-form attributes: fabric shine/texture, button count, lace width,
      # embroidery density, anchor points for the compositor, etc.
      t.jsonb   :metadata, null: false, default: {}

      t.boolean :published, null: false, default: false
      t.string  :processing_status, null: false, default: "pending"
      t.text    :processing_error

      t.references :created_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :design_elements, %i[category published sort_order]
    add_index :design_elements, %i[category slug], unique: true
    add_index :design_elements, :metadata, using: :gin
  end
end
