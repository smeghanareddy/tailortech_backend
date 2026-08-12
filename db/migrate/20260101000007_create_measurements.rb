class CreateMeasurements < ActiveRecord::Migration[7.1]
  def change
    create_table :measurements do |t|
      t.references :user, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }  # designer, if entered for a customer

      t.string  :name, null: false, default: "My Measurements"
      t.string  :unit, null: false, default: "cm"

      t.decimal :height,         precision: 6, scale: 2
      t.decimal :bust,           precision: 6, scale: 2
      t.decimal :waist,          precision: 6, scale: 2
      t.decimal :hip,            precision: 6, scale: 2
      t.decimal :shoulder_width, precision: 6, scale: 2
      t.decimal :neck_size,      precision: 6, scale: 2
      t.decimal :sleeve_length,  precision: 6, scale: 2
      t.decimal :dress_length,   precision: 6, scale: 2

      t.boolean :ai_estimated, null: false, default: false
      t.string  :source, null: false, default: "manual"   # manual / ai_photo / designer
      t.jsonb   :ai_metadata, null: false, default: {}    # confidence, keypoints, model
      t.text    :notes

      t.timestamps
    end

    add_index :measurements, %i[user_id created_at]
  end
end
