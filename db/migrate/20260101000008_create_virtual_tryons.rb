class CreateVirtualTryons < ActiveRecord::Migration[7.1]
  def change
    create_table :virtual_tryons do |t|
      t.references :user,         null: false, foreign_key: true
      t.references :dress_design, null: false, foreign_key: true
      t.references :measurement,  foreign_key: true

      t.integer :status, null: false, default: 0   # pending / processing / completed / failed
      t.string  :result_photo_url                  # external URL, if any
      t.text    :error_message

      t.jsonb   :estimated_measurements, null: false, default: {}
      t.jsonb   :body_landmarks,         null: false, default: {}
      t.integer :processing_ms

      t.timestamps
    end

    add_index :virtual_tryons, %i[user_id created_at]
  end
end
