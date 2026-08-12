module AuthHelpers
  def auth_headers(user)
    { "Authorization" => "Bearer #{JsonWebToken.for_user(user)}" }
  end

  def json
    JSON.parse(response.body)
  end
end
