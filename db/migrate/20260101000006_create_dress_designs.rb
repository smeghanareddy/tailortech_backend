class CreateDressDesigns < ActiveRecord::Migration[7.1]
  def change
    create_table :dress_designs do |t|
      t.references :user,     null: false, foreign_key: true          # owner
      t.references :designer, foreign_key: { to_table: :users }       # who built it

      t.string :name

      # Flat selections — this is exactly what the Design Studio submits.
      t.string :neck_type
      t.string :neck_back_type
      t.string :sleeve_type
      t.string :dress_type
      t.string :fabric
      t.string :pattern
      t.string :color            # legacy / primary colour
      t.string :bodice_color
      t.string :skirt_color

      # Rich component tree: multi-colour stripes, embroidery + lace placement
      # and intensity, buttons, belt. Mirrors the frontend design store.
      t.jsonb :components, null: false, default: {}

      t.integer :status,  null: false, default: 0   # draft / completed / ordered / archived
      t.boolean :public_portfolio, null: false, default: false

      # Layer rendering engine
      t.string   :preview_fingerprint
      t.datetime :preview_rendered_at

      # AI sketch
      t.string   :sketch_url                        # external URL, if any
      t.string   :sketch_status, null: false, default: "pending"
      t.text     :sketch_error
      t.datetime :sketch_generated_at

      t.references :source_design, foreign_key: { to_table: :dress_designs }
      t.integer :version, null: false, default: 1

      t.timestamps
    end

    add_index :dress_designs, %i[user_id status]
    add_index :dress_designs, :preview_fingerprint
    add_index :dress_designs, :components, using: :gin
  end
end
