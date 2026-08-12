module MeasurementSerializer
  module_function

  def call(measurement)
    return nil if measurement.blank?

    base = {
      id: measurement.id,
      name: measurement.name,
      unit: measurement.unit,
      ai_estimated: measurement.ai_estimated,
      source: measurement.source,
      notes: measurement.notes,
      user_id: measurement.user_id,
      created_by_id: measurement.created_by_id,
      created_at: measurement.created_at,
      updated_at: measurement.updated_at
    }

    Measurement::FIELDS.each_with_object(base) do |field, acc|
      value = measurement.public_send(field)
      acc[field] = value&.to_f
    end
  end

  def collection(measurements)
    Array(measurements).map { |m| call(m) }
  end
end
