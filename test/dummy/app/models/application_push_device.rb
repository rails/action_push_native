class ApplicationPushDevice < ActionPush::Device
  # Customize TokenError handling (default: destroy!)
  rescue_from (ActionPush::TokenError) { }
end
