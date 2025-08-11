class ApplicationPushDevice < ActionPush::Device
  # Customize TokenError handling
  rescue_from (ActionPush::TokenError) { }
end
