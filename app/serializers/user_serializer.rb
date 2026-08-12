module UserSerializer
  module_function

  def call(user)
    return nil if user.blank?

    {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      phone: user.phone,
      avatar_url: AttachmentUrl.call(user.avatar),
      city: user.city,
      state: user.state,
      location: user.location,
      bio: user.bio,
      rating: user.rating.to_f,
      reviews_count: user.reviews_count,
      years_experience: user.years_experience,
      specialization: user.specialization,
      created_at: user.created_at
    }
  end

  def collection(users)
    Array(users).map { |user| call(user) }
  end
end
