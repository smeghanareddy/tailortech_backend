Rails.application.config.filter_parameters += %i[
  passw secret token _key crypt salt certificate otp ssn
  password password_confirmation authorization photo
]
