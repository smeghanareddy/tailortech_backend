class EnableExtensions < ActiveRecord::Migration[7.1]
  def change
    enable_extension "pgcrypto"  unless extension_enabled?("pgcrypto")
    enable_extension "citext"    unless extension_enabled?("citext")
    enable_extension "pg_trgm"   unless extension_enabled?("pg_trgm")
  end
end
