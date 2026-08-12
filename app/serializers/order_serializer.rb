module OrderSerializer
  module_function

  def call(order)
    return nil if order.blank?

    {
      id: order.id,
      order_number: order.order_number,
      status: order.status,
      price: order.price,
      currency: order.currency,
      notes: order.notes,
      expected_delivery_on: order.expected_delivery_on,
      contact_phone: order.contact_phone,
      delivery: {
        address_line: order.delivery_address_line,
        city: order.delivery_city,
        state: order.delivery_state,
        pincode: order.delivery_pincode
      },
      dress_design_id: order.dress_design_id,
      measurement_id: order.measurement_id,
      boutique: order.boutique && { id: order.boutique_id, name: order.boutique.name },
      designer: order.designer && { id: order.designer_id, name: order.designer.name },
      created_at: order.created_at,
      updated_at: order.updated_at
    }
  end

  def detail(order)
    call(order).merge(
      design: DressDesignSerializer.detail(order.dress_design),
      measurement: MeasurementSerializer.call(order.measurement),
      design_snapshot: order.design_snapshot,
      measurement_snapshot: order.measurement_snapshot
    )
  end

  def collection(orders)
    Array(orders).map { |o| call(o) }
  end
end
