# Distance search without pulling in a geocoding dependency: a plain
# haversine expression evaluated in PostgreSQL.
module GeoLocatable
  extend ActiveSupport::Concern

  EARTH_RADIUS_KM = 6371.0

  class_methods do
    # radius * acos( cos(lat1)cos(lat2)cos(lng2-lng1) + sin(lat1)sin(lat2) )
    def haversine_sql(lat, lng)
      sanitize_sql_array([<<~SQL.squish, EARTH_RADIUS_KM, lat.to_f, lng.to_f, lat.to_f])
        (?) * acos(
          LEAST(1.0, GREATEST(-1.0,
            cos(radians(?)) * cos(radians(latitude)) *
            cos(radians(longitude) - radians(?)) +
            sin(radians(?)) * sin(radians(latitude))
          ))
        )
      SQL
    end
  end

  included do
    scope :with_coordinates, -> { where.not(latitude: nil).where.not(longitude: nil) }

    # Adds a `distance_km` attribute and orders nearest-first.
    scope :near, lambda { |lat, lng, radius_km = 25|
      distance = haversine_sql(lat, lng)

      with_coordinates
        .select("#{table_name}.*, #{distance} AS distance_km")
        .where("#{distance} <= ?", radius_km.to_f)
        .order(Arel.sql("#{distance} ASC"))
    }
  end

  # Present only on records loaded through `.near`.
  def distance_km
    return nil unless has_attribute?(:distance_km)

    self[:distance_km]&.to_f&.round(2)
  end
end
