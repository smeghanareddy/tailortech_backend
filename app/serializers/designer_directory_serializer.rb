# GET /boutique — the designer directory the React "Designer Boutique" page
# renders. Each card shows the designer's best portfolio piece.
module DesignerDirectorySerializer
  module_function

  def call(designer)
    return nil if designer.blank?

    best = designer.best_design

    {
      id: designer.id,
      name: designer.name,
      bio: designer.bio,
      city: designer.city,
      state: designer.state,
      location: designer.location,
      rating: designer.rating.to_f,
      reviews_count: designer.reviews_count,
      years_experience: designer.years_experience,
      specialization: designer.specialization,
      avatar_url: AttachmentUrl.call(designer.avatar),
      distance_km: designer.distance_km,
      designs_count: designer.portfolio_scope.count,
      best_design: best && {
        id: best.id,
        name: best.name,
        dress_type: best.dress_type,
        sketch_url: best.sketch_display_url
      }
    }
  end

  def detail(designer)
    return nil if designer.blank?

    designs = designer.portfolio_scope
                      .where(public_portfolio: true)
                      .or(designer.portfolio_scope.where(status: :completed))
                      .recent.limit(24)

    call(designer).merge(
      email: designer.email,
      phone: designer.phone,
      designs: DressDesignSerializer.collection(designs)
    )
  end

  def collection(designers)
    Array(designers).map { |d| call(d) }
  end
end
