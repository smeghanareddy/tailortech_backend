# Designer → My Customers list and detail pane.
module CustomerSerializer
  module_function

  def call(customer, link: nil)
    return nil if customer.blank?

    {
      id: customer.id,
      name: customer.name,
      email: customer.email,
      phone: customer.phone,
      city: customer.city,
      measurement_count: customer.measurements.size,
      design_count: customer.dress_designs.size,
      notes: link&.notes,
      last_activity_at: link&.last_activity_at,
      created_at: customer.created_at
    }
  end

  # The expanded row loads measurements + recent designs in one request.
  def detail(customer, link: nil)
    call(customer, link: link).merge(
      measurements: MeasurementSerializer.collection(customer.measurements.recent),
      designs: DressDesignSerializer.collection(customer.dress_designs.recent.limit(12))
    )
  end

  def collection(customers, links: {})
    Array(customers).map { |c| call(c, link: links[c.id]) }
  end
end
