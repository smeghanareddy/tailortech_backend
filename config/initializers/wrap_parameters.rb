# The React client posts flat bodies (and multipart form data for anything with
# a file). Wrapping them under a controller-derived root key would only add
# duplicate params and "unpermitted parameter" noise to the logs.
ActiveSupport.on_load(:action_controller) do
  wrap_parameters false
end
