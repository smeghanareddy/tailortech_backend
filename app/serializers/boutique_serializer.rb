# GET /boutiques — the physical "Nearest Boutique" locator.
module BoutiqueSerializer
  module_function

  def call(boutique)
    return nil if boutique.blank?

    {
      id: boutique.id,
      name: boutique.name,
      description: boutique.description,
      phone: boutique.phone,
      email: boutique.email,
      website: boutique.website,
      address: boutique.full_address,
      city: boutique.city,
      state: boutique.state,
      pincode: boutique.pincode,
      location: boutique.location,
      latitude: boutique.latitude&.to_f,
      longitude: boutique.longitude&.to_f,
      distance_km: boutique.distance_km,
      rating: boutique.rating.to_f,
      reviews_count: boutique.reviews_count,
      services: boutique.services,
      opening_hours: boutique.opening_hours,
      cover_image_url: boutique.cover_image_url,
      navigation_url: boutique.maps_url,
      owner: boutique.owner && { id: boutique.owner_id, name: boutique.owner.name }
    }
  end

  def collection(boutiques)
    Array(boutiques).map { |b| call(b) }
  end
end
