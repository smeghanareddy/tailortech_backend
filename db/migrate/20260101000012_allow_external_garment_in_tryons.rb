class AllowExternalGarmentInTryons < ActiveRecord::Migration[7.1]
  def change
    # A try-on can now be against a garment image linked from elsewhere
    # rather than a saved design, so the design becomes optional.
    change_column_null :virtual_tryons, :dress_design_id, true

    add_column :virtual_tryons, :garment_source_url, :string
    add_column :virtual_tryons, :garment_source_site, :string
  end
end
