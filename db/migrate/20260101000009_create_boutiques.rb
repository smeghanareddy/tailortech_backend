class CreateBoutiques < ActiveRecord::Migration[7.1]
  def change
    create_table :boutiques do |t|
      t.references :owner, foreign_key: { to_table: :users }

      t.string :name, null: false
      t.text   :description
      t.string :phone
      t.string :email
      t.string :website

      t.string  :address_line
      t.string  :city
      t.string  :state
      t.string  :country, default: "India"
      t.string  :pincode
      t.decimal :latitude,  precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6

      t.decimal :rating, precision: 3, scale: 2, null: false, default: 0.0
      t.integer :reviews_count, null: false, default: 0
      t.jsonb   :opening_hours, null: false, default: {}
      t.string  :services, array: true, null: false, default: []

      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :boutiques, %i[city state]
    add_index :boutiques, %i[latitude longitude]
    add_index :boutiques, :active
  end
end
