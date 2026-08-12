class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string  :name,            null: false
      t.citext  :email,           null: false
      t.string  :password_digest, null: false
      t.integer :role,            null: false, default: 0
      t.string  :phone

      # Designer / boutique profile fields — surfaced by GET /boutique
      t.text    :bio
      t.string  :city
      t.string  :state
      t.string  :country, default: "India"
      t.string  :address_line
      t.string  :pincode
      t.decimal :latitude,  precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.decimal :rating, precision: 3, scale: 2, default: 0.0, null: false
      t.integer :reviews_count,   null: false, default: 0
      t.integer :years_experience
      t.string  :specialization

      t.boolean  :active, null: false, default: true
      t.datetime :last_login_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :role
    add_index :users, %i[city state]
  end
end
