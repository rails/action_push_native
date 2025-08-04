class ApplicationPushNotification < ActionPush::Notification
  # Set a custom job queue_name
  queue_as :realtime

  # Controls whether push notifications are enabled
  self.enabled = true
end
