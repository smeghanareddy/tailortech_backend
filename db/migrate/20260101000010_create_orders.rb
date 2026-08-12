class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.references :user,         null: false, foreign_key: true
      t.references :dress_design, null: false, foreign_key: true
      t.references :measurement,  foreign_key: true
      t.references :boutique,     foreign_key: true
      t.references :designer,     foreign_key: { to_table: :users }

      t.string  :order_number, null: false
      t.integer :status, null: false, default: 0   # placed / confirmed / in_tailoring / ready / delivered / cancelled

      t.integer :price_cents, null: false, default: 0
      t.string  :currency, null: false, default: "INR"

      t.text   :notes
      t.date   :expected_delivery_on
      t.string :delivery_address_line
      t.string :delivery_city
      t.string :delivery_state
      t.string :delivery_pincode
      t.string :contact_phone

      # Frozen copy of the design + measurements at the moment of ordering.
      t.jsonb :design_snapshot,      null: false, default: {}
      t.jsonb :measurement_snapshot, null: false, default: {}

      t.timestamps
    end

    add_index :orders, :order_number, unique: true
    add_index :orders, %i[user_id status]
  end
end
