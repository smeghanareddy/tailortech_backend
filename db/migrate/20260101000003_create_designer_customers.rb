class CreateDesignerCustomers < ActiveRecord::Migration[7.1]
  def change
    create_table :designer_customers do |t|
      t.references :designer, null: false, foreign_key: { to_table: :users }
      t.references :customer, null: false, foreign_key: { to_table: :users }
      t.text     :notes
      t.boolean  :created_by_designer, null: false, default: false
      t.datetime :last_activity_at

      t.timestamps
    end

    add_index :designer_customers, %i[designer_id customer_id], unique: true,
              name: "index_designer_customers_uniqueness"
  end
end
