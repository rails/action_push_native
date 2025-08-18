class ApplicationPushDevice < ActionNativePush::Device
  # Customize TokenError handling (default: destroy!)
  rescue_from (ActionNativePush::TokenError) { }
end
