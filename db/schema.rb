# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_01_01_000012) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "boutiques", force: :cascade do |t|
    t.bigint "owner_id"
    t.string "name", null: false
    t.text "description"
    t.string "phone"
    t.string "email"
    t.string "website"
    t.string "address_line"
    t.string "city"
    t.string "state"
    t.string "country", default: "India"
    t.string "pincode"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.decimal "rating", precision: 3, scale: 2, default: "0.0", null: false
    t.integer "reviews_count", default: 0, null: false
    t.jsonb "opening_hours", default: {}, null: false
    t.string "services", default: [], null: false, array: true
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_boutiques_on_active"
    t.index ["city", "state"], name: "index_boutiques_on_city_and_state"
    t.index ["latitude", "longitude"], name: "index_boutiques_on_latitude_and_longitude"
    t.index ["owner_id"], name: "index_boutiques_on_owner_id"
  end

  create_table "compatibility_rules", force: :cascade do |t|
    t.bigint "source_element_id", null: false
    t.bigint "target_element_id"
    t.string "target_category", null: false
    t.string "mode", default: "allow", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_element_id", "target_category", "mode"], name: "index_compat_rules_on_source_target_mode"
    t.index ["source_element_id", "target_element_id", "mode"], name: "index_compat_rules_uniqueness", unique: true
    t.index ["source_element_id"], name: "index_compatibility_rules_on_source_element_id"
    t.index ["target_element_id"], name: "index_compatibility_rules_on_target_element_id"
  end

  create_table "design_elements", force: :cascade do |t|
    t.string "category", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.string "image_url"
    t.integer "z_index", default: 0, null: false
    t.integer "sort_order", default: 0, null: false
    t.string "color_zone"
    t.boolean "supports_color", default: true, null: false
    t.decimal "opacity", precision: 4, scale: 3, default: "1.0", null: false
    t.jsonb "metadata", default: {}, null: false
    t.boolean "published", default: false, null: false
    t.string "processing_status", default: "pending", null: false
    t.text "processing_error"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category", "published", "sort_order"], name: "index_design_elements_on_category_and_published_and_sort_order"
    t.index ["category", "slug"], name: "index_design_elements_on_category_and_slug", unique: true
    t.index ["created_by_id"], name: "index_design_elements_on_created_by_id"
    t.index ["metadata"], name: "index_design_elements_on_metadata", using: :gin
  end

  create_table "designer_customers", force: :cascade do |t|
    t.bigint "designer_id", null: false
    t.bigint "customer_id", null: false
    t.text "notes"
    t.boolean "created_by_designer", default: false, null: false
    t.datetime "last_activity_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_designer_customers_on_customer_id"
    t.index ["designer_id", "customer_id"], name: "index_designer_customers_uniqueness", unique: true
    t.index ["designer_id"], name: "index_designer_customers_on_designer_id"
  end

  create_table "dress_designs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "designer_id"
    t.string "name"
    t.string "neck_type"
    t.string "neck_back_type"
    t.string "sleeve_type"
    t.string "dress_type"
    t.string "fabric"
    t.string "pattern"
    t.string "color"
    t.string "bodice_color"
    t.string "skirt_color"
    t.jsonb "components", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.boolean "public_portfolio", default: false, null: false
    t.string "preview_fingerprint"
    t.datetime "preview_rendered_at"
    t.string "sketch_url"
    t.string "sketch_status", default: "pending", null: false
    t.text "sketch_error"
    t.datetime "sketch_generated_at"
    t.bigint "source_design_id"
    t.integer "version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["components"], name: "index_dress_designs_on_components", using: :gin
    t.index ["designer_id"], name: "index_dress_designs_on_designer_id"
    t.index ["preview_fingerprint"], name: "index_dress_designs_on_preview_fingerprint"
    t.index ["source_design_id"], name: "index_dress_designs_on_source_design_id"
    t.index ["user_id", "status"], name: "index_dress_designs_on_user_id_and_status"
    t.index ["user_id"], name: "index_dress_designs_on_user_id"
  end

  create_table "measurements", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "created_by_id"
    t.string "name", default: "My Measurements", null: false
    t.string "unit", default: "cm", null: false
    t.decimal "height", precision: 6, scale: 2
    t.decimal "bust", precision: 6, scale: 2
    t.decimal "waist", precision: 6, scale: 2
    t.decimal "hip", precision: 6, scale: 2
    t.decimal "shoulder_width", precision: 6, scale: 2
    t.decimal "neck_size", precision: 6, scale: 2
    t.decimal "sleeve_length", precision: 6, scale: 2
    t.decimal "dress_length", precision: 6, scale: 2
    t.boolean "ai_estimated", default: false, null: false
    t.string "source", default: "manual", null: false
    t.jsonb "ai_metadata", default: {}, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_measurements_on_created_by_id"
    t.index ["user_id", "created_at"], name: "index_measurements_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_measurements_on_user_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "dress_design_id", null: false
    t.bigint "measurement_id"
    t.bigint "boutique_id"
    t.bigint "designer_id"
    t.string "order_number", null: false
    t.integer "status", default: 0, null: false
    t.integer "price_cents", default: 0, null: false
    t.string "currency", default: "INR", null: false
    t.text "notes"
    t.date "expected_delivery_on"
    t.string "delivery_address_line"
    t.string "delivery_city"
    t.string "delivery_state"
    t.string "delivery_pincode"
    t.string "contact_phone"
    t.jsonb "design_snapshot", default: {}, null: false
    t.jsonb "measurement_snapshot", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["boutique_id"], name: "index_orders_on_boutique_id"
    t.index ["designer_id"], name: "index_orders_on_designer_id"
    t.index ["dress_design_id"], name: "index_orders_on_dress_design_id"
    t.index ["measurement_id"], name: "index_orders_on_measurement_id"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["user_id", "status"], name: "index_orders_on_user_id_and_status"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.citext "email", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.string "phone"
    t.text "bio"
    t.string "city"
    t.string "state"
    t.string "country", default: "India"
    t.string "address_line"
    t.string "pincode"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.decimal "rating", precision: 3, scale: 2, default: "0.0", null: false
    t.integer "reviews_count", default: 0, null: false
    t.integer "years_experience"
    t.string "specialization"
    t.boolean "active", default: true, null: false
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city", "state"], name: "index_users_on_city_and_state"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "virtual_tryons", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "dress_design_id"
    t.bigint "measurement_id"
    t.integer "status", default: 0, null: false
    t.string "result_photo_url"
    t.text "error_message"
    t.jsonb "estimated_measurements", default: {}, null: false
    t.jsonb "body_landmarks", default: {}, null: false
    t.integer "processing_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "garment_source_url"
    t.string "garment_source_site"
    t.index ["dress_design_id"], name: "index_virtual_tryons_on_dress_design_id"
    t.index ["measurement_id"], name: "index_virtual_tryons_on_measurement_id"
    t.index ["user_id", "created_at"], name: "index_virtual_tryons_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_virtual_tryons_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "boutiques", "users", column: "owner_id"
  add_foreign_key "compatibility_rules", "design_elements", column: "source_element_id"
  add_foreign_key "compatibility_rules", "design_elements", column: "target_element_id"
  add_foreign_key "design_elements", "users", column: "created_by_id"
  add_foreign_key "designer_customers", "users", column: "customer_id"
  add_foreign_key "designer_customers", "users", column: "designer_id"
  add_foreign_key "dress_designs", "dress_designs", column: "source_design_id"
  add_foreign_key "dress_designs", "users"
  add_foreign_key "dress_designs", "users", column: "designer_id"
  add_foreign_key "measurements", "users"
  add_foreign_key "measurements", "users", column: "created_by_id"
  add_foreign_key "orders", "boutiques"
  add_foreign_key "orders", "dress_designs"
  add_foreign_key "orders", "measurements"
  add_foreign_key "orders", "users"
  add_foreign_key "orders", "users", column: "designer_id"
  add_foreign_key "virtual_tryons", "dress_designs"
  add_foreign_key "virtual_tryons", "measurements"
  add_foreign_key "virtual_tryons", "users"
end
