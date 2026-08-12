module JsonWebToken
  ALGORITHM = "HS256".freeze

  class InvalidToken < StandardError; end

  module_function

  def encode(payload, exp: AppConfig.jwt_ttl.from_now)
    claims = payload.dup
    claims[:exp] = exp.to_i
    claims[:iat] = Time.current.to_i
    JWT.encode(claims, AppConfig.jwt_secret, ALGORITHM)
  end

  def decode(token)
    payload, = JWT.decode(token, AppConfig.jwt_secret, true, algorithm: ALGORITHM)
    payload.with_indifferent_access
  rescue JWT::DecodeError, JWT::VerificationError => e
    raise InvalidToken, e.message
  end

  def for_user(user)
    # Braces are required: `encode` takes an `exp:` keyword, so a bare hash
    # here would be parsed as keywords and leave `payload` unfilled.
    encode({ user_id: user.id, role: user.role, email: user.email })
  end
end
