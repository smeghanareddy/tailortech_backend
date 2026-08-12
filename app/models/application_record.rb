class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # "["Name can't be blank", "Email is invalid"]" — the shape the React app
  # reads out of `err.response.data.errors`.
  def error_messages
    errors.full_messages
  end
end
